"""
ChurnAgent: the "Decision Maker" node in your architecture diagram.

Given one raw customer record, it:
  1. runs the churn model
  2. runs the segmentation model
  3. retrieves relevant policy/cluster context (RAG)
  4. assembles a single prompt
  5. asks the LLM to write the business recommendation report

This is deliberately a plain orchestrator, not a tool-calling/ReAct agent --
the "decision" step here is fixed (always run all three, always report),
which matches the workflow diagram you gave me. If you later want the agent
to *choose* which tools to run (e.g. skip segmentation for obviously-safe
customers), that's a small change: wrap the three calls behind an LLM
tool-use step instead of calling them unconditionally in `analyze`.
"""

from tools.churn_tool import ChurnPredictor
from tools.segmentation_tool import SegmentPredictor
from tools.policy_rag import PolicyRAG
from llm_report import LLMReportGenerator


class ChurnAgent:
    def __init__(self):
        self.churn = ChurnPredictor()
        self.segment = SegmentPredictor()
        self.rag = PolicyRAG()
        self.llm = LLMReportGenerator()

    def _build_query(self, raw: dict, churn_result: dict, segment_result: dict) -> str:
        return (
            f"churn risk {churn_result['risk_tier']} "
            f"contract {raw.get('Contract')} "
            f"internet service {raw.get('InternetService')} "
            f"tenure {raw.get('tenure')} months "
            f"cluster {segment_result['cluster_id']} "
            f"payment method {raw.get('PaymentMethod')}"
        )

    def _build_prompt(self, raw: dict, churn_result: dict, segment_result: dict, policy_context: str) -> str:
        customer_summary = "\n".join(f"- {k}: {v}" for k, v in raw.items())
        return f"""CUSTOMER DATA
{customer_summary}

CHURN MODEL OUTPUT
- Churn probability: {churn_result['churn_probability']:.1%}
- Prediction: {churn_result['prediction']}
- Risk tier: {churn_result['risk_tier']}
- Top global drivers of churn (model-wide, not per-customer): {', '.join(churn_result['top_global_features']) or 'n/a'}

SEGMENTATION MODEL OUTPUT
- Cluster ID: {segment_result['cluster_id']}
- Cluster profile: {segment_result['cluster_profile'] or 'n/a'}

RELEVANT COMPANY POLICY / CLUSTER NOTES
{policy_context}

Write the retention report now."""

    def analyze(self, raw_customer: dict) -> dict:
        churn_result = self.churn.predict(raw_customer)
        segment_result = self.segment.predict(raw_customer)

        query = self._build_query(raw_customer, churn_result, segment_result)
        policy_context = self.rag.retrieve(query)

        prompt = self._build_prompt(raw_customer, churn_result, segment_result, policy_context)
        report = self.llm.generate(prompt)

        return {
            "churn": churn_result,
            "segment": segment_result,
            "policy_context": policy_context,
            "report": report,
        }
