"""
StarNutri — Comparación de 3 algoritmos ML
Predice: nivel de riesgo nutricional (BAJO / MEDIO / ALTO)
"""

import numpy as np
import pandas as pd
import joblib
import os
import json
import time
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.ensemble       import RandomForestClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score,
    f1_score, confusion_matrix, roc_auc_score,
    log_loss, classification_report
)
from sklearn.preprocessing   import LabelEncoder, label_binarize
from xgboost                 import XGBClassifier

os.makedirs("models",  exist_ok=True)
os.makedirs("reports", exist_ok=True)

# ── 1. GENERAR DATOS SINTÉTICOS (basados en estándares OMS) ──────────────────
def generate_data(n=1500):
    np.random.seed(42)
    rows = []
    for _ in range(n):
        age     = np.random.randint(2, 14)
        rec_cal = (1000 if age<=3 else 1200 if age<=5
                   else 1400 if age<=8 else 1600 if age<=11 else 1800)

        profile = np.random.choice(["bajo","medio","alto"], p=[0.35,0.40,0.25])

        if profile == "bajo":
            cal   = np.random.normal(rec_cal*0.95, rec_cal*0.08)
            prot  = np.random.normal(40,  8)
            carbs = np.random.normal(160, 20)
            fat   = np.random.normal(45,  8)
            water = np.random.normal(7.5, 1.0)
            meals = np.random.randint(14, 22)
            days  = np.random.randint(5,  8)
        elif profile == "medio":
            cal   = np.random.normal(rec_cal*0.72, rec_cal*0.12)
            prot  = np.random.normal(25,  8)
            carbs = np.random.normal(120, 25)
            fat   = np.random.normal(35, 10)
            water = np.random.normal(5.0, 1.2)
            meals = np.random.randint(8,  15)
            days  = np.random.randint(3,  6)
        else:
            cal   = np.random.normal(rec_cal*0.50, rec_cal*0.15)
            prot  = np.random.normal(14,  6)
            carbs = np.random.normal(80,  30)
            fat   = np.random.normal(22, 10)
            water = np.random.normal(3.0, 1.0)
            meals = np.random.randint(2,  9)
            days  = np.random.randint(1,  4)

        rows.append({
            "age":           max(2, int(age)),
            "avg_calories":  max(0, round(cal,  1)),
            "avg_protein":   max(0, round(prot, 1)),
            "avg_carbs":     max(0, round(carbs,1)),
            "avg_fat":       max(0, round(fat,  1)),
            "avg_water":     max(0, round(water,1)),
            "meals":         max(0, int(meals)),
            "days_tracked":  max(0, int(days)),
            "risk":          profile,
        })
    return pd.DataFrame(rows)

FEATURES = ["age","avg_calories","avg_protein",
            "avg_carbs","avg_fat","avg_water","meals","days_tracked"]

df = generate_data(1500)
le = LabelEncoder()
le.fit(["alto","bajo","medio"])
y  = le.transform(df["risk"])
X  = df[FEATURES].values

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y)

# ── 2. DEFINIR LOS 3 ALGORITMOS ──────────────────────────────────────────────
models = {
    "Random Forest": RandomForestClassifier(
        n_estimators=150, max_depth=8,
        min_samples_split=4, random_state=42,
        class_weight="balanced"
    ),
    "XGBoost": XGBClassifier(
        n_estimators=120, max_depth=6,
        learning_rate=0.1, use_label_encoder=False,
        eval_metric="mlogloss", random_state=42
    ),
    "Red Neuronal (MLP)": MLPClassifier(
        hidden_layer_sizes=(128, 64, 32),
        activation="relu", max_iter=500,
        random_state=42, early_stopping=True
    ),
}

# ── 3. ENTRENAR, EVALUAR Y COMPARAR ─────────────────────────────────────────
results = {}
classes = le.classes_

for name, clf in models.items():
    print(f"\n{'='*50}")
    print(f"  Entrenando: {name}")
    print(f"{'='*50}")

    # Tiempo de entrenamiento
    t0 = time.time()
    clf.fit(X_train, y_train)
    train_time = round((time.time() - t0) * 1000, 2)

    # Predicciones
    t1     = time.time()
    y_pred = clf.predict(X_test)
    inf_ms = round((time.time() - t1) * 1000 / len(X_test), 4)

    y_prob = clf.predict_proba(X_test)

    # Métricas
    acc  = accuracy_score (y_test, y_pred)
    prec = precision_score(y_test, y_pred, average="weighted")
    rec  = recall_score   (y_test, y_pred, average="weighted")
    f1   = f1_score       (y_test, y_pred, average="weighted")
    ll   = log_loss       (y_test, y_prob)
    cm   = confusion_matrix(y_test, y_pred)

    # AUC-ROC multiclase (One-vs-Rest)
    y_bin = label_binarize(y_test, classes=[0,1,2])
    auc   = roc_auc_score(y_bin, y_prob, multi_class="ovr", average="weighted")

    # Cross-validation
    cv = cross_val_score(clf, X, y, cv=5, scoring="f1_weighted")

    results[name] = {
        "model":          clf,
        "accuracy":       round(acc,  4),
        "precision":      round(prec, 4),
        "recall":         round(rec,  4),
        "f1_score":       round(f1,   4),
        "auc_roc":        round(auc,  4),
        "log_loss":       round(ll,   4),
        "cv_f1_mean":     round(cv.mean(), 4),
        "cv_f1_std":      round(cv.std(),  4),
        "train_time_ms":  train_time,
        "inference_ms":   inf_ms,
        "confusion_matrix": cm.tolist(),
    }

    print(classification_report(y_test, y_pred, target_names=classes))
    print(f"  AUC-ROC:       {auc:.4f}")
    print(f"  Log Loss:      {ll:.4f}")
    print(f"  CV F1 (5-fold): {cv.mean():.4f} ± {cv.std():.4f}")
    print(f"  Tiempo entreno: {train_time} ms")
    print(f"  Tiempo inferencia: {inf_ms} ms/muestra")

# ── 4. SELECCIONAR EL MEJOR MODELO ──────────────────────────────────────────
best_name = max(results, key=lambda k: results[k]["f1_score"])
best      = results[best_name]

print(f"\n{'★'*50}")
print(f"  MEJOR MODELO: {best_name}")
print(f"  F1-Score: {best['f1_score']}  |  AUC: {best['auc_roc']}")
print(f"{'★'*50}")

# ── 5. GUARDAR MODELOS Y MÉTRICAS ────────────────────────────────────────────
for name, res in results.items():
    fname = name.lower().replace(" ", "_").replace("(", "").replace(")", "")
    joblib.dump(res["model"], f"models/{fname}.pkl")
    print(f"✓ Guardado: models/{fname}.pkl")

joblib.dump(le, "models/label_encoder.pkl")

metrics_out = {
    k: {m: v for m, v in r.items() if m != "model"}
    for k, r in results.items()
}
metrics_out["best_model"] = best_name

with open("models/metrics.json", "w") as f:
    json.dump(metrics_out, f, indent=2)
print("✓ Guardado: models/metrics.json")

# ── 6. GRÁFICA DE COMPARACIÓN ────────────────────────────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(16, 5))
fig.suptitle("StarNutri — Comparación de Modelos ML", fontsize=15, fontweight="bold")

metric_labels = ["Accuracy","Precision","Recall","F1-Score","AUC-ROC"]
metric_keys   = ["accuracy","precision","recall","f1_score","auc_roc"]
model_names   = list(results.keys())
colors        = ["#7C3AED","#FF6BA1","#5DCCFF"]

# Gráfica de barras por métrica
ax = axes[0]
x  = np.arange(len(metric_labels))
w  = 0.25
for i, (name, res) in enumerate(results.items()):
    vals = [res[k] for k in metric_keys]
    ax.bar(x + i*w, vals, w, label=name, color=colors[i], alpha=0.85)
ax.set_xticks(x + w)
ax.set_xticklabels(metric_labels, rotation=15, ha="right", fontsize=9)
ax.set_ylim(0.5, 1.05)
ax.set_title("Métricas por modelo")
ax.legend(fontsize=8)
ax.set_ylabel("Valor")

# Matriz de confusión del mejor modelo
cm_arr = np.array(best["confusion_matrix"])
sns.heatmap(cm_arr, annot=True, fmt="d", cmap="Purples",
            xticklabels=classes, yticklabels=classes, ax=axes[1])
axes[1].set_title(f"Matriz de Confusión\n{best_name}")
axes[1].set_xlabel("Predicho")
axes[1].set_ylabel("Real")

# F1-Score comparación
f1_vals = [results[n]["f1_score"] for n in model_names]
bars = axes[2].barh(model_names, f1_vals, color=colors, alpha=0.85)
for bar, val in zip(bars, f1_vals):
    axes[2].text(val - 0.02, bar.get_y() + bar.get_height()/2,
                 f"{val:.4f}", va="center", ha="right",
                 color="white", fontweight="bold", fontsize=10)
axes[2].set_xlim(0.5, 1.05)
axes[2].set_title("F1-Score por modelo")
axes[2].set_xlabel("F1-Score")

plt.tight_layout()
plt.savefig("reports/comparacion_modelos.png", dpi=150, bbox_inches="tight")
print("✓ Gráfica guardada: reports/comparacion_modelos.png")
plt.close()

print("\n✅ Entrenamiento completo. Ejecuta main.py para iniciar la API.")