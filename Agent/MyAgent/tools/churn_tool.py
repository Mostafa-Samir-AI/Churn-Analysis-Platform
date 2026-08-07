"""
Churn prediction tool.

⚠️ VERIFY BEFORE PRODUCTION USE ⚠️
I don't have access to your actual model_metadata.json / feature_names.json /
training notebook, so `_engineer_features` below is a best-guess reconstruction
of a *typical* preprocessing pipeline for this exact dataset:
    - binary Yes/No columns -> 1/0
    - gender -> 1/0
    - Contract -> your ordinal_encoder_contract.pkl
    - remaining multi-category columns -> one-hot (pd.get_dummies)
    - tenure / MonthlyCharges / TotalCharges -> your standard_scaler.pkl
    - final frame reindexed to feature_names.json (fills any missing
      one-hot column with 0), which guarantees column ORDER matches
      training even if my one-hot naming differs slightly from yours.

The reindex-to-feature_names step is the safety net: as long as
feature_names.json is the authoritative list of columns the model was
trained on, mismatched engineering will surface as obviously-wrong
predictions (e.g. everything landing in one class) rather than a silent
shape error -- so smoke-test this against a few known-labeled rows from
your training set before trusting it.

Open model_metadata.json once and confirm: encoding scheme, scaler columns,
and whether TotalCharges was engineered differently (e.g. tenure*Monthly).
Adjust `_engineer_features` to match if it disagrees with what's below.
"""

import json
import joblib
from pathlib import Path

import numpy as np
import pandas as pd

from config import (
    BEST_MODEL_PATH,
    MODEL_METADATA_PATH,
    FEATURE_NAMES_PATH,
    CONTRACT_ENCODER_PATH,
    STANDARD_SCALER_PATH,
    BINARY_YES_NO_FIELDS,
)

_ONEHOT_COLS = [
    "MultipleLines", "InternetService", "OnlineSecurity", "OnlineBackup",
    "DeviceProtection", "TechSupport", "StreamingTV", "StreamingMovies",
    "PaymentMethod",
]
_NUMERIC_COLS = ["tenure", "MonthlyCharges", "TotalCharges"]


class ChurnPredictor:
    def __init__(self):
        missing = [p for p in [BEST_MODEL_PATH, FEATURE_NAMES_PATH,
                                CONTRACT_ENCODER_PATH, STANDARD_SCALER_PATH] if not Path(p).exists()]
        if missing:
            raise FileNotFoundError(
                f"Missing classification artifacts: {missing}. "
                f"Check config.CLASSIFICATION_MODEL_DIR / CLASSIFICATION_PREP_DIR."
            )

        # with open(BEST_MODEL_PATH, "rb") as f:
        #     self.model = pickle.load(f)
        # with open(CONTRACT_ENCODER_PATH, "rb") as f:
        #     self.contract_encoder = pickle.load(f)
        # with open(STANDARD_SCALER_PATH, "rb") as f:
        #     self.scaler = pickle.load(f)
        # with open(FEATURE_NAMES_PATH, "r") as f:
        #     self.feature_names = json.load(f)

        self.model = joblib.load(BEST_MODEL_PATH)
        self.contract_encoder = joblib.load(CONTRACT_ENCODER_PATH)
        self.scaler = joblib.load(STANDARD_SCALER_PATH)

        with open(FEATURE_NAMES_PATH, "r") as f:
            self.feature_names = json.load(f)

            self.metadata = {}
            if Path(MODEL_METADATA_PATH).exists():
                with open(MODEL_METADATA_PATH, "r") as f:
                    self.metadata = json.load(f)

    def _engineer_features(self, raw: dict) -> pd.DataFrame:
        df = pd.DataFrame([raw]).copy()

        # Numeric coercion (TotalCharges sometimes arrives as a string with
        # blanks for tenure==0 customers in the original dataset).
        for col in _NUMERIC_COLS:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")
        if "TotalCharges" in df.columns and df["TotalCharges"].isna().any():
            df["TotalCharges"] = df["tenure"] * df["MonthlyCharges"]

        # Binary Yes/No -> 1/0
        yn_map = {"Yes": 1, "No": 0}
        for col in BINARY_YES_NO_FIELDS:
            if col in df.columns:
                df[col] = df[col].map(yn_map)

        if "gender" in df.columns:
            df["gender"] = df["gender"].map({"Male": 1, "Female": 0})

        if "SeniorCitizen" in df.columns:
            df["SeniorCitizen"] = df["SeniorCitizen"].astype(int)

        # Ordinal-encode Contract with your fitted encoder
        if "Contract" in df.columns:
            df["Contract"] = self.contract_encoder.transform(df[["Contract"]])

        # One-hot the remaining categoricals
        present_onehot = [c for c in _ONEHOT_COLS if c in df.columns]
        df = pd.get_dummies(df, columns=present_onehot)

        # Scale numeric columns with your fitted scaler
        present_numeric = [c for c in _NUMERIC_COLS if c in df.columns]
        if present_numeric:
            df[present_numeric] = self.scaler.transform(df[present_numeric])

        # Align to the exact training column order/set
        df = df.reindex(columns=self.feature_names, fill_value=0)
        return df

    def predict(self, raw: dict) -> dict:
        X = self._engineer_features(raw)
        proba = float(self.model.predict_proba(X)[0][1])
        label = "Churn" if proba >= 0.5 else "No Churn"
        risk_tier = "High" if proba >= 0.7 else "Medium" if proba >= 0.4 else "Low"

        top_features = []
        if hasattr(self.model, "feature_importances_"):
            importances = self.model.feature_importances_
            top_idx = np.argsort(importances)[::-1][:5]
            top_features = [self.feature_names[i] for i in top_idx]

        return {
            "churn_probability": round(proba, 4),
            "prediction": label,
            "risk_tier": risk_tier,
            "top_global_features": top_features,
        }
