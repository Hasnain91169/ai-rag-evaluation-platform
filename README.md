# Rails-Hosted RAG Evaluation Platform (MVP)

This project is a complete MVP with:
- `rails_app/`: Rails 7 system of record + dashboard
- `python_service/`: FastAPI compute plane for chunking/embeddings/retrieval/generation/evals
- `postgres`: PostgreSQL with `pgvector`
- `vercel_demo/`: Vercel-hosted Next.js live demo focused on trace introspection

## Vercel Demo (Recommended for Sharing)

If you need a live demo URL for recruiters/PMs, deploy `vercel_demo/`.

Quick path:
1. Import this repo in Vercel.
2. Set Root Directory to `vercel_demo`.
3. Deploy.
4. (Optional) attach Vercel Postgres for persistent traces.

Detailed steps: `vercel_demo/README.md`

## Architecture

- Rails stores documents, chunks, traces, retrieval results, responses, eval runs, and metrics.
- Rails calls FastAPI using `Faraday`.
- FastAPI uses `pgvector` for vector search when available; falls back to in-memory cosine search automatically.
- LLM generation is deterministic (stubbed) for reliable demos.
- Retrieval supports optional reranking (`hybrid` or `lexical`) and logs both `base_score` and final score.
- Generation returns chunk citations, and online eval includes attribution-aware metrics.

## Quick Start

1. Start services:

```bash
docker compose up --build
```

2. In another terminal, create DB, migrate, seed:

```bash
docker compose exec rails bundle exec rails db:create db:migrate db:seed
```

3. Open apps:
- Rails dashboard: http://localhost:3000
- FastAPI docs: http://localhost:8000/docs

## MVP Flows

1. Ingest document:
- Go to `Ingest Document`
- Paste text and submit
- Rails calls `/chunk`, `/embed`, persists chunks, then `/index`

2. Ask question (RAG):
- Go to `Ask Question`
- Enter query and submit
- Rails creates `QueryTrace`, calls `/retrieve`, stores `RetrievalResult`
- Rails calls `/generate`, stores `ModelResponse`
- Rails runs online eval via `/eval/online`, stores metrics in an `online` `EvalRun`

3. Offline evaluation:
- From Dashboard or Eval Runs page, click `Run Offline Eval`
- Rails sends seeded dataset (`EvalQuestion`) to `/eval/offline`
- Rails stores aggregate metrics in an `offline` `EvalRun`

4. Diagnose failures:
- Open any trace detail page
- Diagnosis tag logic:
  - `ranking_issue`: base retrieval hit is high but reranked hit is low
  - `retrieval_issue`: low retrieval hit rate + low faithfulness
  - `prompting_issue`: retrieval is good but attribution/faithfulness is low
  - `ok`: otherwise

5. Prompt version testing:
- Choose prompt version from dropdown on `Ask Question`
- Dashboard shows average faithfulness/attribution/latency by prompt version

## Seed Data

`db/seeds.rb` creates:
- 3 product-style documents
- 15 evaluation questions
- gold chunk IDs for each question

It also attempts to index seeded chunks into FastAPI vector index.

## Tests

### Python

```bash
docker compose exec python pytest -q
```

Includes:
- retrieval test
- eval metric test

### Rails

```bash
docker compose exec rails bundle exec rspec
```

Includes:
- one model spec (`QueryTrace` diagnosis)
- one request spec (`POST /query_traces`)

## Environment Variables

### Rails
- `POSTGRES_HOST` (default `postgres`)
- `POSTGRES_PORT` (default `5432`)
- `POSTGRES_USER` (default `postgres`)
- `POSTGRES_PASSWORD` (default `postgres`)
- `POSTGRES_DB` (default `rag_eval_development`)
- `PYTHON_SERVICE_URL` (default `http://python:8000`)
- `PYTHON_SERVICE_TIMEOUT` (default `8`)
- `RERANK_ENABLED` (default `true`)
- `RERANK_METHOD` (default `hybrid`; options `hybrid` or `lexical`)

### Python
- `DATABASE_URL` (default `postgresql://postgres:postgres@postgres:5432/rag_eval_development`)
- `EMBEDDING_DIM` (default `16`)

## Simplifications (Intentional MVP)

- Dashboard uses trend tables (not JS charts) to keep stack simple and deterministic.
- Generation is a deterministic stub (`/generate`) rather than paid API/model call.
- Faithfulness/attribution are deterministic heuristic proxies; attribution is scoped to cited chunks.
