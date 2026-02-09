from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_online_eval_uses_citation_scoped_attribution():
    response = client.post(
        "/eval/online",
        json={
            "query": "What is the timeout?",
            "response_text": "Based on retrieved docs: The timeout is 8 hours.",
            "expected_answer": "The timeout is 8 hours.",
            "gold_chunk_ids": [10],
            "retrieved_chunk_ids": [10, 11],
            "base_retrieved_chunk_ids": [10, 11],
            "cited_chunk_ids": [10],
            "retrieved_chunks": [
                {"chunk_id": 10, "content": "The timeout is 8 hours for SSO sessions."},
                {"chunk_id": 11, "content": "Refunds are accepted within 14 days."},
            ],
            "latency_ms": 123.45,
        },
    )

    metrics = response.json()["metrics"]

    assert response.status_code == 200
    assert metrics["retrieval_hit_rate"] == 1.0
    assert metrics["base_retrieval_hit_rate"] == 1.0
    assert metrics["latency_ms"] == 123.45
    assert 0.0 <= metrics["attribution_score"] <= 1.0
    assert 0.0 <= metrics["citation_coverage"] <= 1.0
    assert metrics["hallucination_rate"] == round(1 - metrics["attribution_score"], 4)
    assert 0.0 <= metrics["answer_accuracy"] <= 1.0
