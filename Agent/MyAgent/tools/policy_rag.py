"""
Lightweight RAG over the two company knowledge docs (policies.txt, clusters.txt).

Kept intentionally simple per your "simple as possible" brief: no vector DB,
no embeddings API call. Docs are split into paragraph-sized chunks and
retrieved with TF-IDF cosine similarity, which is plenty for a couple of
short reference documents. If these docs grow large / numerous later, swap
this for a real vector store without touching the rest of the agent --
`retrieve()` is the only method the agent calls.
"""

import re
from pathlib import Path

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from config import POLICIES_TXT, CLUSTERS_TXT


class PolicyRAG:
    def __init__(self):
        self.chunks = []
        self.sources = []

        for path, label in [(POLICIES_TXT, "policies.txt"), (CLUSTERS_TXT, "clusters.txt")]:
            path = Path(path)
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8")
            # split on blank lines -> paragraph-ish chunks
            parts = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
            self.chunks.extend(parts)
            self.sources.extend([label] * len(parts))

        self.vectorizer = None
        self.matrix = None
        if self.chunks:
            self.vectorizer = TfidfVectorizer(stop_words="english")
            self.matrix = self.vectorizer.fit_transform(self.chunks)

    def retrieve(self, query: str, k: int = 4) -> str:
        if not self.chunks:
            return "(No policy/cluster knowledge base found at Agent/policies/.)"

        q_vec = self.vectorizer.transform([query])
        sims = cosine_similarity(q_vec, self.matrix)[0]
        top_idx = sims.argsort()[::-1][:k]

        results = []
        for i in top_idx:
            if sims[i] <= 0:
                continue
            results.append(f"[{self.sources[i]}] {self.chunks[i]}")

        return "\n\n---\n\n".join(results) if results else "(No closely matching policy found.)"
