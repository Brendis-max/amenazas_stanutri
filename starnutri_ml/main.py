from fastapi import FastAPI
import joblib
import json

app = FastAPI()

model = None
le = None
metrics_cache = {}

@app.on_event("startup")
async def startup_event():
    global model, le, metrics_cache

    # Cargar métricas
    with open("models/metrics.json") as f:
        all_metrics = json.load(f)

    best_name = all_metrics["best_model"]

    fname = (
        best_name.lower()
        .replace(" ", "_")
        .replace("(", "")
        .replace(")", "")
    )

    # Cargar modelo ganador
    model = joblib.load(f"models/{fname}.pkl")

    # Cargar encoder
    le = joblib.load("models/label_encoder.pkl")

    metrics_cache = all_metrics

    print(f"✅ Modelo cargado: {best_name}")


@app.get("/")
def home():
    return {
        "message": "StarNutri API funcionando"
    }


@app.get("/metrics")
def get_metrics():
    return metrics_cache