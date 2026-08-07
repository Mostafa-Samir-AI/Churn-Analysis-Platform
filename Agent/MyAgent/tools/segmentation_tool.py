"""
Customer segmentation tool.

⚠️ VERIFY BEFORE PRODUCTION USE ⚠️
This one is safer than churn_tool.py because your preprocessing_pipeline.joblib
is (presumably) an end-to-end sklearn Pipeline that does its own
encoding/scaling -- I just need to hand it a DataFrame with the right raw
columns in the right order, which is what feature_names.joblib is for.

Two assumptions to confirm on your side:
  1. feature_names.joblib lists the RAW input columns the pipeline expects
     (not the post-transform columns). That's the standard convention for
     saving alongside a preprocessing pipeline, but confirm it.
  2. The pipeline can handle a single-row DataFrame at inference time
     (some pipelines fitted with column-dependent steps like PCA are fine
     with this; just flagging it as a thing to smoke-test).

If cluster_labels.txt / clusters.txt use a different cluster numbering
than kmeans.predict() returns, add a mapping dict here.
"""

import json
from pathlib import Path

import joblib
import pandas as pd

from config import (
    KMEANS_MODEL_PATH,
    CUSTOMER_SEGMENTS_CSV,
    CLUSTER_PIPELINE_PATH,
    CLUSTER_FEATURE_NAMES_PATH,
)


class SegmentPredictor:
    def __init__(self):
        missing = [p for p in [KMEANS_MODEL_PATH, CLUSTER_PIPELINE_PATH,
                                CLUSTER_FEATURE_NAMES_PATH] if not Path(p).exists()]
        if missing:
            raise FileNotFoundError(
                f"Missing clustering artifacts: {missing}. "
                f"Check config.CLUSTERING_MODEL_DIR / CLUSTERING_PREP_DIR."
            )

        self.kmeans = joblib.load(KMEANS_MODEL_PATH)
        self.pipeline = joblib.load(CLUSTER_PIPELINE_PATH)
        self.feature_names = joblib.load(CLUSTER_FEATURE_NAMES_PATH)

        self.segment_profile = None
        if Path(CUSTOMER_SEGMENTS_CSV).exists():
            self.segment_profile = pd.read_csv(CUSTOMER_SEGMENTS_CSV)

    def predict(self, raw: dict) -> dict:
        df = pd.DataFrame([raw]).copy()

        # TotalCharges numeric safety (same as churn_tool)
        if "TotalCharges" in df.columns:
            df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")
            if df["TotalCharges"].isna().any() and {"tenure", "MonthlyCharges"} <= set(df.columns):
                df["TotalCharges"] = df["tenure"] * df["MonthlyCharges"]

        # Align to the raw columns the pipeline was fit on
        df = df.reindex(columns=list(self.feature_names))

        X = self.pipeline.transform(df)
        cluster_id = int(self.kmeans.predict(X)[0])

        summary = None
        if self.segment_profile is not None:
            id_col = next((c for c in self.segment_profile.columns
                           if c.lower() in ("cluster", "cluster_id", "segment")), None)
            if id_col is not None:
                match = self.segment_profile[self.segment_profile[id_col] == cluster_id]
                if not match.empty:
                    summary = match.iloc[0].to_dict()

        return {"cluster_id": cluster_id, "cluster_profile": summary}
