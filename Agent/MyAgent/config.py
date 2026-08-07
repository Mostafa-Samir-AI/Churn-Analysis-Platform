"""
Central configuration for the Churn Analysis Agent.

This file assumes MyAgent lives at: Agent/policies/MyAgent/  (per your tree).
If you move the folder, just set the CHURN_PROJECT_ROOT env var to your repo root
instead of relying on the relative walk-up below.

    export CHURN_PROJECT_ROOT=/absolute/path/to/repo
"""

import os
from pathlib import Path

# --- Resolve project root -----------------------------------------------
_env_root = os.environ.get("CHURN_PROJECT_ROOT")
if _env_root:
    PROJECT_ROOT = Path(_env_root).resolve()
else:
    # MyAgent -> policies -> Agent -> <repo root>
    PROJECT_ROOT = Path(__file__).resolve().parents[2]

# --- Classification (XGBoost churn model) --------------------------------
CLASSIFICATION_MODEL_DIR = PROJECT_ROOT / "models" / "classification_alg" / "classification_model"
CLASSIFICATION_PREP_DIR = PROJECT_ROOT / "models" / "classification_alg" / "preprocessing"

BEST_MODEL_PATH = CLASSIFICATION_MODEL_DIR / "best_model.pkl"
MODEL_METADATA_PATH = CLASSIFICATION_MODEL_DIR / "model_metadata.json"
FEATURE_NAMES_PATH = CLASSIFICATION_PREP_DIR / "feature_names.json"
CONTRACT_ENCODER_PATH = CLASSIFICATION_PREP_DIR / "ordinal_encoder_contract.pkl"
STANDARD_SCALER_PATH = CLASSIFICATION_PREP_DIR / "standard_scaler.pkl"

# --- Clustering (KMeans segmentation model) -------------------------------
CLUSTERING_MODEL_DIR = PROJECT_ROOT / "models" / "clustering_alg" / "clustering_model"
CLUSTERING_PREP_DIR = PROJECT_ROOT / "models" / "clustering_alg" / "preprocessing"

KMEANS_MODEL_PATH = CLUSTERING_MODEL_DIR / "kmeans_model.joblib"
CUSTOMER_SEGMENTS_CSV = CLUSTERING_MODEL_DIR / "customer_segments.csv"
CLUSTER_PIPELINE_PATH = CLUSTERING_PREP_DIR / "preprocessing_pipeline.joblib"
CLUSTER_FEATURE_NAMES_PATH = CLUSTERING_PREP_DIR / "feature_names.joblib"

# --- Policy / cluster knowledge base (RAG source docs) --------------------
POLICIES_DIR = PROJECT_ROOT / "Agent" / "policies"
POLICIES_TXT = POLICIES_DIR / "policies.txt"
CLUSTERS_TXT = POLICIES_DIR / "clusters.txt"

# --- LLM ------------------------------------------------------------------
# --- LLM (Ollama) ----------------------------------------------------------
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get(
    "OLLAMA_MODEL",
    "phi3.5:3.8b-mini-instruct-q4_K_M"
)

# --- Raw input schema (matches WA_Fn-UseC_-Telco-Customer-Churn.csv) -------
# Used to drive the Gradio form and to validate/order agent input.
BINARY_YES_NO_FIELDS = ["Partner", "Dependents", "PhoneService", "PaperlessBilling"]

TRIPLE_STATE_FIELDS = [  # "No" / "Yes" / "No internet service"
    "OnlineSecurity", "OnlineBackup", "DeviceProtection",
    "TechSupport", "StreamingTV", "StreamingMovies",
]

CATEGORICAL_OPTIONS = {
    "gender": ["Female", "Male"],
    "MultipleLines": ["No", "No phone service", "Yes"],
    "InternetService": ["DSL", "Fiber optic", "No"],
    "Contract": ["Month-to-month", "One year", "Two year"],
    "PaymentMethod": [
        "Bank transfer (automatic)", "Credit card (automatic)",
        "Electronic check", "Mailed check",
    ],
    **{f: ["No", "No internet service", "Yes"] for f in TRIPLE_STATE_FIELDS},
    **{f: ["No", "Yes"] for f in BINARY_YES_NO_FIELDS},
}

NUMERIC_FIELDS = ["tenure", "MonthlyCharges", "TotalCharges"]
