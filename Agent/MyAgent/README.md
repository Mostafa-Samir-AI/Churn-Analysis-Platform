# Churn Analysis Agent

A simple agentic workflow: Gradio UI → Agent (decision maker) → [Churn model, Segmentation model, Policy RAG] → LLM → Business recommendation report.

```
Agent/policies/MyAgent/
├── config.py            # all paths + LLM settings, one place to edit
├── agent.py              # ChurnAgent: orchestrates the two models + RAG + LLM
├── llm_report.py         # Anthropic API call that writes the final report
├── app.py                # Gradio UI entrypoint
├── tools/
│   ├── churn_tool.py      # wraps best_model.pkl + preprocessing
│   ├── segmentation_tool.py  # wraps kmeans_model.joblib + pipeline
│   └── policy_rag.py      # TF-IDF retrieval over policies.txt / clusters.txt
└── requirements.txt
```

## Setup

```bash
cd Agent/policies/MyAgent
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
python app.py
```

`config.py` assumes this folder lives at `Agent/policies/MyAgent/` in your repo
(three levels below the repo root, matching your tree). If you move it, set:

```bash
export CHURN_PROJECT_ROOT=/absolute/path/to/repo
```

Optional: `export ANTHROPIC_MODEL=claude-...` to pick a specific model (defaults
to `claude-sonnet-4-5` — check your console for the exact model strings you have
access to and update if needed).

## ⚠️ Things I could not verify (please check before trusting output)

I built and smoke-tested this entire pipeline against **mock artifacts** I
generated myself (same file names/formats as yours), because your actual
`.pkl`/`.joblib` files and `policies.txt`/`clusters.txt` aren't in this
environment. The code runs end-to-end and is structured defensively, but two
spots are reconstructions of what I'd expect your training pipeline to look
like, not things I read from your actual metadata:

1. **`tools/churn_tool.py` → `_engineer_features`**
   I guessed a standard encoding scheme (Yes/No → 1/0, `Contract` → your
   ordinal encoder, everything else one-hot, numeric columns → your scaler),
   then **reindex the final frame to `feature_names.json`** so column
   order/set always matches training regardless of exactly how I built it.
   This makes wrong *encoding values* (not wrong *shape*) the main risk.
   **Action item:** run 3–5 known-labeled rows from your training set through
   `ChurnPredictor.predict()` and confirm the probabilities look sane before
   using this on real customers. If they don't, open `model_metadata.json`
   and adjust `_engineer_features` to match your real encoding.

2. **`tools/segmentation_tool.py`**
   Assumes `feature_names.joblib` lists the *raw* input columns your
   `preprocessing_pipeline.joblib` expects, and that the pipeline is a
   standard sklearn `Pipeline` you can call `.transform()` on directly.
   Same smoke-test advice applies.

Everything else — the RAG retrieval, the agent orchestration, the LLM
prompt/report generation, the Gradio UI and its field-by-field mapping to
your CSV schema — was built and tested end-to-end in this environment and
should work as-is.

## How it works

1. User fills in a customer profile in the Gradio form (fields match your
   Telco churn CSV schema exactly: gender, tenure, Contract, etc).
2. `ChurnAgent.analyze()` runs, in order:
   - `ChurnPredictor.predict()` → probability, prediction, risk tier
   - `SegmentPredictor.predict()` → cluster id + profile
   - `PolicyRAG.retrieve()` → top-k relevant chunks from `policies.txt` /
     `clusters.txt`, using TF-IDF cosine similarity against a query built
     from risk tier, cluster id, and key account fields
3. All of the above gets assembled into one prompt and sent to Claude, which
   writes a short retention report (verdict, why, segment implication,
   recommended action).
4. Gradio displays the churn result, segment, retrieved policy context, and
   the final report.

## Extending later

- **Batch mode:** add a CSV-upload tab to `app.py` that loops
  `ChurnAgent.analyze()` over rows — the agent/tool code doesn't need to
  change, just the UI.
- **Real vector RAG:** if `policies.txt`/`clusters.txt` grow large, swap the
  TF-IDF logic inside `PolicyRAG.retrieve()` for a real vector store; nothing
  else in the codebase touches that class's internals.
- **Tool-calling agent:** right now `ChurnAgent.analyze()` always runs all
  three tools in a fixed order. If you want the LLM itself to decide which
  tools to call (e.g. skip segmentation for very low-risk customers), wrap
  the three tool calls behind an Anthropic tool-use loop instead of the
  direct calls in `agent.py`.
