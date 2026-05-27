from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import json
import time
import uuid

app = FastAPI(title="StarNutri ML API")

model = None
le = None
metrics_cache = {}
results_store = {}

# ── Modelo de entrada con las columnas REALES ──────────────────
class PredictionInput(BaseModel):
    age: float
    avg_calories: float
    avg_protein: float
    avg_carbs: float
    avg_fat: float
    avg_water: float
    meals: float
    days_tracked: float

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
        data.age,
        data.avg_calories,
        data.avg_protein,
        data.avg_carbs,
        data.avg_fat,
        data.avg_water,
        data.meals,
        data.days_tracked
    ]]

    start = time.time()
    prediction_encoded = model.predict(features)[0]
    elapsed_ms = round((time.time() - start) * 1000, 2)

    label = le.inverse_transform([prediction_encoded])[0]

    result_id = str(uuid.uuid4())
    result = {
        "id": result_id,
        "prediccion": label,
        "riesgo_nutricional": label.upper(),
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