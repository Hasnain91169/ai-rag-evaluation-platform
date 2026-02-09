import hashlib
import os
import re
import threading
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import numpy as np
import psycopg
from fastapi import FastAPI
from pydantic import BaseModel, Field

EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "16"))
DEFAULT_DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@postgres:5432/rag_eval_development",
)

STOPWORDS = {
    "the",
    "a",
    "an",
    "is",
    "are",
    "of",
    "to",
    "and",
    "for",
    "in",
    "on",
    "with",
    "by",
    "be",
    "as",
    "at",
    "or",
    "that",
    "this",
}


class EmbedRequest(BaseModel):
    text: str


class ChunkRequest(BaseModel):
    document: str
    chunk_size: int = 500
    overlap: int = 60


class IndexChunk(BaseModel):
    chunk_id: int
    document_id: int
    content: str
    embedding: Optional[List[float]] = None


class IndexRequest(BaseModel):
    chunks: List[IndexChunk]


class RetrieveRequest(BaseModel):
    query: str
    top_k: int = 5
    rerank: bool = True
    rerank_method: str = "hybrid"


class ContextChunk(BaseModel):
    chunk_id: int
    content: str


class GenerateRequest(BaseModel):
    query: str
    contexts: List[ContextChunk]
    model_name: str = "stub-rag-1"
    prompt_version: str = "v1"
    prompt_template: Optional[str] = None


class OfflineEvalItem(BaseModel):
    question: str
    expected_answer: str
    gold_chunk_ids: List[int] = Field(default_factory=list)


class OfflineEvalRequest(BaseModel):
    dataset: List[OfflineEvalItem]
    top_k: int = 5


class OnlineEvalRequest(BaseModel):
    query: str
    response_text: str
    expected_answer: Optional[str] = None
    gold_chunk_ids: List[int] = Field(default_factory=list)
    retrieved_chunk_ids: List[int] = Field(default_factory=list)
    base_retrieved_chunk_ids: List[int] = Field(default_factory=list)
    cited_chunk_ids: List[int] = Field(default_factory=list)
    retrieved_chunks: List[ContextChunk] = Field(default_factory=list)
    latency_ms: float = 0.0


@dataclass
class RetrievalRow:
    chunk_id: int
    content: str
    base_score: float
    base_rank: int


def normalize_tokens(text: str) -> List[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def normalize_content_tokens(text: str) -> List[str]:
    return [t for t in normalize_tokens(text) if t not in STOPWORDS]


def deterministic_embedding(text: str, dims: int = EMBEDDING_DIM) -> List[float]:
    tokens = normalize_tokens(text)
    vec = np.zeros(dims, dtype=np.float64)
    if not tokens:
        return vec.tolist()

    for token in tokens:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        for i in range(dims):
            vec[i] += digest[i]

    norm = np.linalg.norm(vec)
    if norm > 0:
        vec = vec / norm
    return vec.round(8).tolist()


def cosine_similarity(a: List[float], b: List[float]) -> float:
    va = np.array(a, dtype=np.float64)
    vb = np.array(b, dtype=np.float64)
    denom = np.linalg.norm(va) * np.linalg.norm(vb)
    if denom == 0:
        return 0.0
    return float(np.dot(va, vb) / denom)


def lexical_overlap_score(query: str, content: str) -> float:
    query_tokens = set(normalize_content_tokens(query))
    content_tokens = set(normalize_content_tokens(content))
    if not query_tokens:
        return 0.0
    overlap = len(query_tokens & content_tokens)
    return overlap / len(query_tokens)


def chunk_text(document: str, chunk_size: int, overlap: int) -> List[str]:
    text = re.sub(r"\s+", " ", document).strip()
    if not text:
        return []

    chunks: List[str] = []
    start = 0
    size = max(chunk_size, 120)
    overlap = max(min(overlap, size // 2), 0)

    while start < len(text):
        end = min(start + size, len(text))
        window = text[start:end]
        if end < len(text):
            split = window.rfind(". ")
            if split > size * 0.4:
                end = start + split + 1
                window = text[start:end]
        chunks.append(window.strip())
        if end >= len(text):
            break
        start = max(end - overlap, start + 1)

    return chunks


def coverage_score(answer: str, contexts: List[str]) -> float:
    answer_tokens = normalize_content_tokens(answer)
    if not answer_tokens:
        return 1.0

    context_tokens = set()
    for text in contexts:
        context_tokens.update(normalize_content_tokens(text))

    if not context_tokens:
        return 0.0

    covered = sum(1 for token in answer_tokens if token in context_tokens)
    return round(covered / len(answer_tokens), 4)


def accuracy_proxy(answer: str, expected: Optional[str]) -> float:
    if not expected:
        return 0.0
    answer_tokens = set(normalize_content_tokens(answer))
    expected_tokens = set(normalize_content_tokens(expected))
    if not expected_tokens:
        return 0.0
    overlap = len(answer_tokens & expected_tokens)
    return round(overlap / len(expected_tokens), 4)


def select_context(query: str, contexts: List[ContextChunk]) -> Optional[ContextChunk]:
    if not contexts:
        return None

    q_tokens = set(normalize_content_tokens(query))
    best_context = contexts[0]
    best_score = -1

    for ctx in contexts:
        c_tokens = set(normalize_content_tokens(ctx.content))
        score = len(q_tokens & c_tokens)
        if score > best_score:
            best_score = score
            best_context = ctx

    return best_context


def best_rank(ids: List[int], gold_ids: List[int]) -> Optional[int]:
    if not ids or not gold_ids:
        return None
    gold_set = set(gold_ids)
    for idx, chunk_id in enumerate(ids, start=1):
        if chunk_id in gold_set:
            return idx
    return None


class VectorIndex:
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.mode = "memory"
        self._lock = threading.Lock()
        self._memory: Dict[int, Dict[str, Any]] = {}
        self._conn = None
        self._setup_pgvector()

    def _setup_pgvector(self) -> None:
        try:
            conn = psycopg.connect(self.db_url, autocommit=True)
            with conn.cursor() as cur:
                cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
                cur.execute(
                    f"""
                    CREATE TABLE IF NOT EXISTS rag_vector_index (
                        chunk_id BIGINT PRIMARY KEY,
                        document_id BIGINT NOT NULL,
                        content TEXT NOT NULL,
                        embedding VECTOR({EMBEDDING_DIM}) NOT NULL,
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
            self._conn = conn
            self.mode = "pgvector"
        except Exception:
            self.mode = "memory"
            self._conn = None

    @staticmethod
    def _vector_literal(embedding: List[float]) -> str:
        return "[" + ",".join(f"{x:.8f}" for x in embedding) + "]"

    def index(self, chunks: List[IndexChunk]) -> int:
        if self.mode == "pgvector" and self._conn is not None:
            with self._conn.cursor() as cur:
                for chunk in chunks:
                    emb = chunk.embedding or deterministic_embedding(chunk.content)
                    cur.execute(
                        """
                        INSERT INTO rag_vector_index (chunk_id, document_id, content, embedding, updated_at)
                        VALUES (%s, %s, %s, %s::vector, NOW())
                        ON CONFLICT (chunk_id)
                        DO UPDATE SET
                          document_id = EXCLUDED.document_id,
                          content = EXCLUDED.content,
                          embedding = EXCLUDED.embedding,
                          updated_at = NOW()
                        """,
                        (
                            chunk.chunk_id,
                            chunk.document_id,
                            chunk.content,
                            self._vector_literal(emb),
                        ),
                    )
            return len(chunks)

        with self._lock:
            for chunk in chunks:
                emb = chunk.embedding or deterministic_embedding(chunk.content)
                self._memory[chunk.chunk_id] = {
                    "document_id": chunk.document_id,
                    "content": chunk.content,
                    "embedding": emb,
                }
        return len(chunks)

    def retrieve(self, query_embedding: List[float], candidate_k: int) -> List[RetrievalRow]:
        candidate_k = max(1, min(candidate_k, 50))

        if self.mode == "pgvector" and self._conn is not None:
            vector_literal = self._vector_literal(query_embedding)
            with self._conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT chunk_id, content, 1 - (embedding <=> %s::vector) AS score
                    FROM rag_vector_index
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                    """,
                    (vector_literal, candidate_k),
                )
                rows = cur.fetchall()

            return [
                RetrievalRow(
                    chunk_id=int(row[0]),
                    content=str(row[1]),
                    base_score=float(row[2]),
                    base_rank=idx + 1,
                )
                for idx, row in enumerate(rows)
            ]

        with self._lock:
            scored = []
            for chunk_id, entry in self._memory.items():
                score = cosine_similarity(query_embedding, entry["embedding"])
                scored.append((chunk_id, score, entry["content"]))

        scored.sort(key=lambda x: x[1], reverse=True)
        return [
            RetrievalRow(
                chunk_id=chunk_id,
                base_score=float(score),
                content=content,
                base_rank=idx + 1,
            )
            for idx, (chunk_id, score, content) in enumerate(scored[:candidate_k])
        ]


app = FastAPI(title="RAG Compute Plane", version="0.2.0")
index_store = VectorIndex(DEFAULT_DB_URL)


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "index_mode": index_store.mode}


@app.post("/embed")
def embed(req: EmbedRequest) -> Dict[str, List[float]]:
    return {"embedding": deterministic_embedding(req.text)}


@app.post("/chunk")
def chunk(req: ChunkRequest) -> Dict[str, List[str]]:
    return {"chunks": chunk_text(req.document, req.chunk_size, req.overlap)}


@app.post("/index")
def index(req: IndexRequest) -> Dict[str, int | str]:
    count = index_store.index(req.chunks)
    return {"indexed": count, "mode": index_store.mode}


@app.post("/retrieve")
def retrieve(req: RetrieveRequest) -> Dict[str, List[Dict[str, Any]]]:
    top_k = max(1, min(req.top_k, 20))
    candidate_k = max(top_k, min(top_k * 3, 50))
    query_emb = deterministic_embedding(req.query)
    base_rows = index_store.retrieve(query_emb, candidate_k)

    rows = []
    for row in base_rows:
        lexical_score = lexical_overlap_score(req.query, row.content)
        if req.rerank:
            if req.rerank_method == "lexical":
                rerank_score = lexical_score
            else:
                rerank_score = 0.7 * row.base_score + 0.3 * lexical_score
        else:
            rerank_score = row.base_score

        rows.append(
            {
                "chunk_id": row.chunk_id,
                "content": row.content,
                "base_rank": row.base_rank,
                "base_score": round(row.base_score, 6),
                "lexical_score": round(lexical_score, 6),
                "rerank_score": round(rerank_score, 6),
            }
        )

    if req.rerank:
        rows.sort(key=lambda x: x["rerank_score"], reverse=True)
    else:
        rows.sort(key=lambda x: x["base_score"], reverse=True)

    final_rows = rows[:top_k]
    for idx, row in enumerate(final_rows, start=1):
        row["rank"] = idx
        row["score"] = row["rerank_score"]

    return {"results": final_rows}


@app.post("/generate")
def generate(req: GenerateRequest) -> Dict[str, Any]:
    best_context = select_context(req.query, req.contexts)

    if best_context is None:
        answer = "I could not find relevant context to answer this query."
        cited_chunk_ids: List[int] = []
    else:
        sentence = best_context.content.split(". ")[0].strip()
        answer = f"Based on retrieved docs: {sentence}."
        cited_chunk_ids = [best_context.chunk_id]

    return {
        "answer": answer,
        "model_name": req.model_name,
        "prompt_version": req.prompt_version,
        "cited_chunk_ids": cited_chunk_ids,
    }


@app.post("/eval/online")
def eval_online(req: OnlineEvalRequest) -> Dict[str, Dict[str, float]]:
    if req.gold_chunk_ids:
        hit = 1.0 if set(req.gold_chunk_ids) & set(req.retrieved_chunk_ids) else 0.0
        base_hit = (
            1.0 if set(req.gold_chunk_ids) & set(req.base_retrieved_chunk_ids) else 0.0
        )
    else:
        hit = 1.0 if req.retrieved_chunk_ids else 0.0
        base_hit = 1.0 if req.base_retrieved_chunk_ids else 0.0

    retrieved_texts = [chunk.content for chunk in req.retrieved_chunks]
    faithfulness = coverage_score(req.response_text, retrieved_texts)

    cited_contexts = [
        chunk.content
        for chunk in req.retrieved_chunks
        if chunk.chunk_id in set(req.cited_chunk_ids)
    ]

    if req.cited_chunk_ids:
        citation_coverage = coverage_score(req.response_text, cited_contexts)
        attribution_score = citation_coverage
    elif req.retrieved_chunks:
        citation_coverage = 0.0
        attribution_score = 0.0
    else:
        citation_coverage = 0.0
        attribution_score = 0.0

    hallucination_rate = round(1.0 - attribution_score, 4)

    answer_accuracy = accuracy_proxy(req.response_text, req.expected_answer)
    if not req.expected_answer:
        answer_accuracy = attribution_score

    base_rank = best_rank(req.base_retrieved_chunk_ids, req.gold_chunk_ids)
    final_rank = best_rank(req.retrieved_chunk_ids, req.gold_chunk_ids)
    ranking_shift = 0.0
    if base_rank is not None and final_rank is not None:
        ranking_shift = float(final_rank - base_rank)

    metrics = {
        "retrieval_hit_rate": round(hit, 4),
        "base_retrieval_hit_rate": round(base_hit, 4),
        "ranking_shift": round(ranking_shift, 4),
        "latency_ms": round(float(req.latency_ms), 4),
        "faithfulness": round(faithfulness, 4),
        "citation_coverage": round(citation_coverage, 4),
        "attribution_score": round(attribution_score, 4),
        "hallucination_rate": round(hallucination_rate, 4),
        "answer_accuracy": round(answer_accuracy, 4),
    }
    return {"metrics": metrics}


@app.post("/eval/offline")
def eval_offline(req: OfflineEvalRequest) -> Dict[str, Dict[str, float] | List[Dict[str, Any]]]:
    per_item: List[Dict[str, Any]] = []
    agg: Dict[str, float] = {}

    for item in req.dataset:
        t0 = time.perf_counter()
        retrieved = retrieve(
            RetrieveRequest(query=item.question, top_k=req.top_k, rerank=True, rerank_method="hybrid")
        )["results"]
        contexts = [
            ContextChunk(chunk_id=int(r["chunk_id"]), content=str(r["content"]))
            for r in retrieved
        ]
        generated = generate(GenerateRequest(query=item.question, contexts=contexts))
        latency_ms = (time.perf_counter() - t0) * 1000.0

        metrics = eval_online(
            OnlineEvalRequest(
                query=item.question,
                response_text=generated["answer"],
                expected_answer=item.expected_answer,
                gold_chunk_ids=item.gold_chunk_ids,
                retrieved_chunk_ids=[int(r["chunk_id"]) for r in retrieved],
                base_retrieved_chunk_ids=[
                    int(r["chunk_id"]) for r in sorted(retrieved, key=lambda x: int(x["base_rank"]))
                ],
                cited_chunk_ids=[int(cid) for cid in generated.get("cited_chunk_ids", [])],
                retrieved_chunks=contexts,
                latency_ms=latency_ms,
            )
        )["metrics"]

        for key, value in metrics.items():
            agg[key] = agg.get(key, 0.0) + float(value)

        per_item.append(
            {
                "question": item.question,
                "answer": generated["answer"],
                "cited_chunk_ids": generated.get("cited_chunk_ids", []),
                "metrics": metrics,
                "retrieved_chunk_ids": [int(r["chunk_id"]) for r in retrieved],
            }
        )

    count = max(len(req.dataset), 1)
    aggregate = {key: round(value / count, 4) for key, value in agg.items()}
    return {"aggregate": aggregate, "per_item": per_item}
