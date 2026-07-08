from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta, timezone
import joblib
import json
import time
import os
import firebase_admin
from firebase_admin import credentials, firestore

app = FastAPI(title="StarNutri ML API")

# ── CONEXIÓN A FIREBASE ────────────────────────────────────────
try:
    if not firebase_admin._apps:
        if os.path.exists("firebase-credentials.json"):
            cred = credentials.Certificate("firebase-credentials.json")
            firebase_admin.initialize_app(cred)
            print("🚀 Conectado a Firebase en modo Local")
        else:
            cred = credentials.Certificate({
                "type": "service_account",
                "project_id": os.getenv("FIREBASE_PROJECT_ID"),
                "private_key": os.getenv("FIREBASE_PRIVATE_KEY", "").replace('\\n', '\n'),
                "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
            })
            firebase_admin.initialize_app(cred)
            print("☁️ Conectado a Firebase en modo Railway")
except Exception as e:
    print(f"⚠️ Alerta Firebase: {e}")

db = firestore.client() if firebase_admin._apps else None

model = None
le = None
metrics_cache = {}

# ── MODELO DE ENTRADA (para /predict manual) ─────────────────────
class PredictionInput(BaseModel):
    user_id: str
    child_id: Optional[str] = None
    child_name: Optional[str] = None
    age: float
    avg_calories: float
    avg_protein: float
    avg_carbs: float
    avg_fat: float
    avg_water: float
    meals: float
    days_tracked: float

# ── STARTUP ────────────────────────────────────────────────────
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
    print(f"✅ Modelo cargado con éxito: {best_name}")

# ── ENDPOINTS BÁSICOS ────────────────────────────────────────────
@app.get("/")
def home():
    return {"message": "StarNutri ML API funcionando y lista para Firebase ✅"}

@app.get("/metrics")
def get_metrics():
    return metrics_cache

@app.get("/health")
def health_check():
    return {"status": "healthy", "database_connected": db is not None}

# ── LÓGICA CENTRAL DE PREDICCIÓN (reutilizable) ──────────────────
def _run_prediction(
    user_id: str,
    child_id: Optional[str],
    child_name: Optional[str],
    age: float,
    avg_calories: float,
    avg_protein: float,
    avg_carbs: float,
    avg_fat: float,
    avg_water: float,
    meals: float,
    days_tracked: float,
):
    if model is None:
        raise HTTPException(status_code=503, detail="Modelo no cargado")

    features = [[age, avg_calories, avg_protein, avg_carbs, avg_fat, avg_water, meals, days_tracked]]

    start = time.time()
    prediction_encoded = model.predict(features)[0]
    elapsed_ms = round((time.time() - start) * 1000, 2)

    label = le.inverse_transform([prediction_encoded])[0]

    probabilidades = {}
    if hasattr(model, "predict_proba"):
        probs = model.predict_proba(features)[0]
        probabilidades = {cls: round(float(p), 4) for cls, p in zip(le.classes_, probs)}

    result = {
        "user_id": user_id,
        "child_id": child_id,
        "child_name": child_name,
        "prediccion": str(label),
        "riesgo_nutricional": str(label).upper(),
        "probabilidades": probabilidades,
        "tiempo_ms": elapsed_ms,
        "modelo_usado": metrics_cache.get("best_model", "desconocido"),
        "timestamp": firestore.SERVER_TIMESTAMP if db else time.time(),
        "input": {
            "age": age,
            "avg_calories": avg_calories,
            "avg_protein": avg_protein,
            "avg_carbs": avg_carbs,
            "avg_fat": avg_fat,
            "avg_water": avg_water,
            "meals": meals,
            "days_tracked": days_tracked,
        },
    }

    if not db:
        raise HTTPException(status_code=500, detail="Servicio de base de datos no disponible")

    try:
        ref = (
            db.collection("users").document(user_id)
              .collection("predicciones").document()
        )
        ref.set(result)
        return {
            "id_documento_firestore": ref.id,
            "status": "Guardado exitosamente en la nube (Firebase)",
            "tiempo_ejecucion": f"{elapsed_ms} ms",
            "resultado": str(label),
            "probabilidades": probabilidades,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al escribir en Firestore: {e}")


@app.post("/predict")
def predict(data: PredictionInput):
    """Endpoint manual: recibe los datos ya calculados (usado por Flutter)."""
    return _run_prediction(
        user_id=data.user_id,
        child_id=data.child_id,
        child_name=data.child_name,
        age=data.age,
        avg_calories=data.avg_calories,
        avg_protein=data.avg_protein,
        avg_carbs=data.avg_carbs,
        avg_fat=data.avg_fat,
        avg_water=data.avg_water,
        meals=data.meals,
        days_tracked=data.days_tracked,
    )


# ── NUEVO: LEE LOS REPORTES YA GUARDADOS EN FIRESTORE Y PREDICE ──
def _agregar_reportes(reports_docs, window_days: int = 14):
    """Misma lógica que predictRisk() en Dart: agrupa por día y promedia."""
    since = datetime.now(timezone.utc) - timedelta(days=window_days)
    daily = {}
    total_reports = 0

    for doc in reports_docs:
        d = doc.to_dict()
        ts = d.get("timestamp")
        if ts is None:
            continue
        # Firestore Timestamp -> datetime
        date = ts if isinstance(ts, datetime) else ts.ToDatetime() if hasattr(ts, "ToDatetime") else None
        if date is None:
            continue
        if date.tzinfo is None:
            date = date.replace(tzinfo=timezone.utc)
        if date < since:
            continue

        day_key = f"{date.year}-{date.month}-{date.day}"
        total_reports += 1
        bucket = daily.setdefault(day_key, {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0, "water": 0.0})

        bucket["calories"] += float(d.get("totalCalories", 0) or 0)
        bucket["protein"]  += float(d.get("totalProtein", 0) or 0)
        bucket["carbs"]    += float(d.get("totalCarbs", 0) or 0)
        bucket["fat"]      += float(d.get("totalFat", 0) or 0)

        water = float(d.get("waterGlasses", 0) or 0)
        if water > bucket["water"]:
            bucket["water"] = water  # no se suma, es el máximo del día

    if not daily:
        return None

    days_tracked = len(daily)
    def avg(key):
        return sum(v[key] for v in daily.values()) / days_tracked

    return {
        "avg_calories": avg("calories"),
        "avg_protein": avg("protein"),
        "avg_carbs": avg("carbs"),
        "avg_fat": avg("fat"),
        "avg_water": avg("water"),
        "meals": float(total_reports),
        "days_tracked": float(days_tracked),
    }


@app.post("/process-reports/{user_id}/{child_id}")
def process_reports(user_id: str, child_id: str, window_days: int = 14):
    """
    Lee los reportes YA GUARDADOS en Firestore para un niño específico,
    calcula los promedios y genera+guarda la predicción.
    Úsalo desde /docs (Swagger) para procesar reportes históricos.
    """
    if not db:
        raise HTTPException(status_code=500, detail="Firebase no conectado")

    # 1. Buscar datos del niño (nombre y edad) en users/{uid}/children/{childId}
    child_ref = db.collection("users").document(user_id).collection("children").document(child_id)
    child_doc = child_ref.get()
    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Niño no encontrado en Firestore")

    child_data = child_doc.to_dict()
    child_name = child_data.get("name", "Sin nombre")
    age = float(child_data.get("age", 0))

    # 2. Leer los reportes de ese niño
    reports_ref = (
        db.collection("users").document(user_id)
          .collection("reports")
          .where("childId", "==", child_id)
    )
    reports_docs = list(reports_ref.stream())

    if not reports_docs:
        raise HTTPException(status_code=404, detail="No hay reportes para este niño")

    agregados = _agregar_reportes(reports_docs, window_days=window_days)
    if agregados is None:
        raise HTTPException(status_code=404, detail="No hay reportes dentro de la ventana de días indicada")

    # 3. Correr el modelo y guardar en Firestore
    return _run_prediction(
        user_id=user_id,
        child_id=child_id,
        child_name=child_name,
        age=age,
        **agregados,
    )


@app.post("/process-all-reports")
def process_all_reports(window_days: int = 14):
    """
    Recorre TODOS los usuarios y TODOS sus niños, procesando los reportes
    ya existentes en Firestore y generando predicciones para cada uno.
    Ideal para correr una sola vez y "poblar" el dashboard con el histórico.
    """
    if not db:
        raise HTTPException(status_code=500, detail="Firebase no conectado")

    resultados = []
    errores = []

    users_docs = db.collection("users").stream()
    for user_doc in users_docs:
        user_id = user_doc.id
        children_docs = db.collection("users").document(user_id).collection("children").stream()

        for child_doc in children_docs:
            child_id = child_doc.id
            try:
                res = process_reports(user_id, child_id, window_days=window_days)
                resultados.append({"user_id": user_id, "child_id": child_id, "resultado": res})
            except HTTPException as e:
                errores.append({"user_id": user_id, "child_id": child_id, "error": e.detail})
            except Exception as e:
                errores.append({"user_id": user_id, "child_id": child_id, "error": str(e)})

    return {
        "procesados": len(resultados),
        "con_error_o_sin_datos": len(errores),
        "resultados": resultados,
        "errores": errores,
    }