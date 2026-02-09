from fastapi.testclient import TestClient

from main import app, index_store

client = TestClient(app)


def setup_function():
    index_store.mode = "memory"
    index_store._memory.clear()


def test_retrieve_returns_scores_with_rerank_fields():
    payload = {
        "chunks": [
            {
                "chunk_id": 1,
                "document_id": 1,
                "content": "The default SSO session timeout is 8 hours.",
            },
            {
                "chunk_id": 2,
                "document_id": 1,
                "content": "Refund requests are accepted within 14 days.",
            },
        ]
    }
    client.post("/index", json=payload)

    response = client.post(
        "/retrieve",
        json={
            "query": "When are refund requests accepted?",
            "top_k": 2,
            "rerank": True,
            "rerank_method": "lexical",
        },
    )
    body = response.json()

    assert response.status_code == 200
    assert len(body["results"]) == 2
    assert body["results"][0]["chunk_id"] == 2
    assert "base_score" in body["results"][0]
    assert "rerank_score" in body["results"][0]
    assert "base_rank" in body["results"][0]
