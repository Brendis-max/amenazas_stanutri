from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import json
import time
import uuid
from typing import Optional

app = FastAPI(title="StarNutri ML API")

model = None
le = None
metrics_cache = {}

# ── Modelo de entrada ──────────────────────────────────────────
class PredictionInput(BaseModel):
    edad: float
    peso: float
    talla: float
    imc: float
    hemoglobina: float
    colesterol: float
    glucosa: float

# ── Almacenamiento en memoria (mientras no hay Firestore) ───────
results_store = {}

# ── Startup ────────────────────────────────────────────────────
@app.on_event("startup")
async def startup_event():
    global model, le, metrics_cache
    with open("models/metrics.json") as f:
        all_metrics = json.load(f)
    best_name = all_metrics["best_model"]
    fname = (
        best_name.lower()
        .replace(" ", "_")
        .replace("(", "")
        .replace(")", "")
    )
    model = joblib.load(f"models/{fname}.pkl")
    le = joblib.load("models/label_encoder.pkl")
    metrics_cache = all_metrics
    print(f"✅ Modelo cargado: {best_name}")

# ── Endpoints ──────────────────────────────────────────────────
@app.get("/")
def home():
    return {"message": "StarNutri ML API funcionando ✅"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/metrics")
def get_metrics():
    return metrics_cache

@app.post("/predict")
def predict(data: PredictionInput):
    if model is None:
        raise HTTPException(status_code=503, detail="Modelo no cargado")

    features = [[
        data.edad,
        data.peso,
        data.talla,
        data.imc,
        data.hemoglobina,
        data.colesterol,
        data.glucosa
    ]]

    start = time.time()
    prediction_encoded = model.predict(features)[0]
    elapsed_ms = round((time.time() - start) * 1000, 2)

    label = le.inverse_transform([prediction_encoded])[0]

    # Guardar resultado
    result_id = str(uuid.uuid4())
    result = {
        "id": result_id,
        "prediccion": label,
        "tiempo_ms": elapsed_ms,
        "modelo_usado": metrics_cache.get("best_model", "desconocido"),
        "input": data.dict()
    }
    results_store[result_id] = result

    return result

@app.get("/results/{result_id}")
def get_result(result_id: str):
    if result_id not in results_store:
        raise HTTPException(status_code=404, detail="Resultado no encontrado")
    return results_store[result_id]