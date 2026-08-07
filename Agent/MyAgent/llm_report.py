"""
Turns the combined agent context (customer data + churn result + segment
result + retrieved policy) into a business-facing recommendation report
using the Anthropic API.
"""

import os
import requests

from config import OLLAMA_HOST, OLLAMA_MODEL
_SYSTEM_PROMPT = (
    "You are a senior customer-retention analyst at a telecom company. "
    "You are given a customer's churn-risk prediction, their behavioral "
    "segment, and relevant excerpts from internal retention policy. "
    "Write a concise, decision-ready report for a retention team lead: "
    "1) a one-line verdict, 2) why this customer is at risk (grounded in "
    "the fields given, not invented facts), 3) which segment they belong "
    "to and what that implies, 4) a specific recommended action drawn from "
    "the policy excerpts. Keep it under 250 words. No fluff, no disclaimers."
)


class LLMReportGenerator:
    def __init__(self, model : str = ""):
        self.model = model or OLLAMA_MODEL
        self.host = OLLAMA_HOST.rstrip("/")

    def generate(self, prompt: str, max_tokens: int = 800) -> str:

        response = requests.post(
            f"{self.host}/api/chat",
            json={
                "model": self.model,
                "stream": False,
                "options": {
                    "num_predict": max_tokens
                },
                "messages": [
                    {
                        "role": "system",
                        "content": _SYSTEM_PROMPT
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            },
            timeout=300
        )

        response.raise_for_status()

        return response.json()["message"]["content"].strip()