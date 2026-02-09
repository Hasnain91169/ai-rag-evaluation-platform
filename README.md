# AI RAG Evaluation Platform

**🔗 Live Demo:** [https://ai-rag-evaluation-platform.vercel.app](https://ai-rag-evaluation-platform.vercel.app)

## Overview

This project demonstrates how to build production-minded evaluation and observability infrastructure for RAG-based AI systems. Rather than focusing on model training, it focuses on measuring, diagnosing, and improving AI quality over time — including retrieval failures, prompting issues, and latency drift.

The project includes both a full Rails+Python stack for local development and a standalone Next.js demo deployed on Vercel for live demonstrations.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Rails Application (System of Record)                      │
│  ├── Document & chunk management                           │
│  ├── Query trace ingestion & storage                       │
│  ├── Eval run orchestration                                │
│  └── Admin dashboard (metrics visualization)               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ├──> PostgreSQL + pgvector
                   │    ├── query_traces (every RAG interaction)
                   │    ├── retrieval_results (chunks + scores)
                   │    ├── model_responses (answers + citations)
                   │    ├── eval_runs (batch evaluation results)
                   │    ├── eval_metrics (per-trace metrics)
                   │    └── vector index (semantic search)
                   │
                   └──> Python FastAPI Service
                        ├── Chunking & embedding (deterministic)
                        ├── Vector retrieval (pgvector or in-memory)
                        ├── Reranking (hybrid or lexical)
                        ├── Generation (deterministic stub)
                        └── Evaluation metrics computation
```

**Key design decisions:**
- Rails handles persistence, orchestration, and UI
- Python FastAPI handles compute-intensive retrieval and eval tasks
- PostgreSQL + pgvector for vector similarity search (with in-memory fallback)
- Deterministic embeddings and generation for reliable demos without API costs
- Clear separation between trace collection and evaluation
- Optional Vercel deployment for shareable live demos

## Problems This Solves

This platform addresses core challenges in production RAG systems:

- **Detects retrieval vs prompting vs ranking failures**: Separates "we didn't find the right documents" from "we found them but generated a bad response" from "we found them initially but ranked them poorly"
- **Measures quality drift over time**: Tracks metrics across queries to catch degradation before users complain
- **Provides confidence in AI changes before shipping**: Test prompt versions, model changes, or retrieval strategy updates with real data
- **Enables both offline and online evaluation loops**: Batch evaluate on test sets, then validate with live traffic
- **Supports prompt versioning**: A/B test different prompt templates and see metrics side-by-side

## Failure Diagnosis Logic

The system automatically classifies failures based on combined signals:

| Base Retrieval | Reranked Result | Faithfulness | Diagnosis |
|----------------|-----------------|--------------|-----------|
| Good hit | Poor rerank | Any | **Ranking issue** – initial retrieval found it but reranker demoted it |
| Low hit rate | Any | Low | **Retrieval failure** – documents missing or embeddings misaligned |
| High hit rate | High | Low | **Prompting failure** – model hallucinating despite good context |
| High hit rate | High | High | ✅ **OK** – acceptable response |

**Metrics tracked per trace:**
- **Retrieval hit rate**: % of queries where relevant documents appear in top-k
- **Faithfulness**: Does the answer stay grounded in the retrieved context? (no hallucinations)
- **Hallucination rate**: % of response that introduces facts not in context
- **Answer accuracy**: Token overlap with expected answer (when available)
- **Latency**: Time from query to response (p50, p95, p99 tracked)

**Why this matters**: Without failure classification, all bad answers look the same. But the fix is completely different:
- Retrieval failure → improve embeddings, chunking strategy, or search algorithm
- Prompting failure → adjust prompt template, add grounding instructions, or change model
- Ranking failure → tune reranking weights or switch reranking strategy
- OK but slow → optimize retrieval or caching

## How This Would Scale in Production

While this is a demonstration project, it's designed with production patterns in mind:

**Async evaluation pipeline**
- Background jobs process evaluations without blocking API responses
- Batch processing for historical trace analysis
- Scheduled jobs for daily/weekly quality reports

**Model comparison framework**
- Run parallel evaluations against multiple models or prompt versions
- A/B test prompt changes with statistical significance
- Compare retrieval strategies (semantic search vs. hybrid vs. keyword)

**Deployment safety**
- Feature flags for gradual rollout of prompt changes
- Canary releases with automatic rollback on quality degradation
- Shadow mode evaluation (test new logic without affecting production)

**Observability integration**
- Structured logging for trace analysis
- Prometheus-compatible metrics export
- Alerting on quality threshold violations

## Quick Start (Two Options)

### Option 1: Live Demo (Recommended for Recruiters/Demos)

Visit the deployed Vercel demo: **[https://ai-rag-evaluation-platform.vercel.app](https://ai-rag-evaluation-platform.vercel.app)**

Try sample queries:
- "What is the default SSO session timeout?"
- "When are invoices generated?"
- "How often do database backups run?"

Each query shows:
- Retrieved chunks with similarity scores and rankings
- Generated answer with model/prompt info
- Real-time evaluation metrics (faithfulness, hallucination rate, accuracy)
- Automatic failure classification badge

The demo uses deterministic stubbed models (no API costs) with optional Vercel Postgres persistence.

### Option 2: Full Stack Local Development

**Prerequisites:**
- Docker & Docker Compose
- (Optional) PostgreSQL with pgvector extension

**Setup:**

```bash
# Clone the repository
git clone https://github.com/yourusername/ai-rag-evaluation-platform.git
cd ai-rag-evaluation-platform

# Start all services (Rails, Python FastAPI, PostgreSQL with pgvector)
docker compose up --build

# In another terminal, set up the database
docker compose exec rails bundle exec rails db:create db:migrate db:seed

# Access the applications
# Rails dashboard: http://localhost:3000
# FastAPI docs: http://localhost:8000/docs
```

**Seed data includes:**
- 3 sample enterprise SaaS product docs
- 15 evaluation questions with gold chunk IDs
- Sample query traces with metrics

## Usage Examples

### 1. Ingest Documents

**Via Rails UI:**
- Navigate to "Ingest Document"
- Paste document text
- System automatically chunks, embeds, and indexes

**Via API:**
```bash
curl -X POST http://localhost:3000/documents \
  -H "Content-Type: application/json" \
  -d '{"document": {"title": "Product Guide", "content": "..."}}'
```

### 2. Run RAG Queries

**Via Rails UI:**
- Go to "Ask Question"
- Select prompt version (v1, v2, v3)
- Enter query
- View trace with retrieved chunks, answer, and eval metrics

**Via API:**
```bash
curl -X POST http://localhost:3000/query_traces \
  -H "Content-Type: application/json" \
  -d '{"query_trace": {"query_text": "What is the SSO timeout?", "prompt_version": "v1"}}'
```

### 3. Run Offline Evaluations

```bash
# Batch evaluate on test set
curl -X POST http://localhost:3000/eval_runs \
  -H "Content-Type: application/json" \
  -d '{"eval_run": {"eval_type": "offline"}}'
```

Results show aggregate metrics across the evaluation dataset:
- Average retrieval hit rate
- Average faithfulness
- Average accuracy
- Failure mode distribution

### 4. Compare Prompt Versions

The dashboard shows metrics grouped by prompt version:

| Prompt | Avg Faithfulness | Avg Accuracy | Avg Latency | Traces |
|--------|------------------|--------------|-------------|--------|
| v1     | 0.82 | 0.71 | 145ms | 47 |
| v2     | 0.89 | 0.73 | 152ms | 38 |
| v3     | 0.91 | 0.78 | 148ms | 21 |

This enables A/B testing of prompt changes with real metrics.

## Project Structure

```
├── rails_app/              # Rails 7 system of record
│   ├── app/
│   │   ├── models/         # ActiveRecord models
│   │   │   ├── query_trace.rb       # RAG query + metadata
│   │   │   ├── retrieval_result.rb  # Retrieved chunks + scores
│   │   │   ├── model_response.rb    # Generated answers
│   │   │   ├── eval_run.rb          # Batch evaluation runs
│   │   │   ├── eval_metric.rb       # Per-trace metrics
│   │   │   └── prompt_template.rb   # Prompt versioning
│   │   ├── controllers/    # API + UI endpoints
│   │   ├── services/       # Python client + RAG pipeline
│   │   └── views/          # Admin dashboard (ERB templates)
│   ├── db/migrate/         # Database schema
│   └── spec/               # RSpec tests
│
├── python_service/         # FastAPI evaluation service
│   ├── main.py             # FastAPI app + eval logic
│   │   ├── /chunk          # Text chunking
│   │   ├── /embed          # Deterministic embeddings
│   │   ├── /retrieve       # Vector search + reranking
│   │   ├── /generate       # Stubbed generation
│   │   ├── /eval/online    # Per-query evaluation
│   │   └── /eval/offline   # Batch evaluation
│   └── tests/              # Pytest test suite
│
├── vercel_demo/            # Standalone Next.js demo
│   ├── app/
│   │   ├── api/            # Serverless API routes
│   │   │   ├── query/      # RAG pipeline
│   │   │   └── traces/     # Trace listing
│   │   └── page.tsx        # Main UI
│   └── lib/
│       ├── rag.ts          # Retrieval + generation
│       ├── corpus.ts       # Sample documents
│       └── store.ts        # In-memory or Vercel Postgres
│
└── docker-compose.yml      # Orchestration (Rails, Python, Postgres)
```

## Technology Stack

**Backend (Rails + Python):**
- **Rails 7.1** – API layer, admin UI, orchestration, trace persistence
- **PostgreSQL 14+** – Trace storage, time-series queries
- **pgvector** – Vector similarity search extension
- **Python 3.10 + FastAPI** – Evaluation compute, retrieval logic
- **Pydantic** – Request/response validation
- **NumPy** – Vector operations

**Frontend (Vercel Demo):**
- **Next.js 14** (App Router) – React framework
- **TypeScript** – Type safety
- **Vercel Serverless Functions** – API routes
- **Vercel Postgres** (optional) – Persistent trace storage
- **Tailwind CSS** – Styling

**Testing:**
- **RSpec** – Rails model and request specs
- **Pytest** – Python service tests

**Key Features:**
- Deterministic embeddings (no external API calls)
- Stubbed generation (reliable, free demos)
- Automatic pgvector fallback to in-memory search
- Reranking support (hybrid or lexical)
- Prompt versioning and A/B testing
- Offline and online evaluation modes

## Key Features Demonstrated

✅ **Full RAG pipeline** – Document ingestion, chunking, embedding, retrieval, generation  
✅ **Trace-level observability** – Every query captured with full context  
✅ **Multi-metric evaluation** – Retrieval hit rate, faithfulness, hallucination rate, accuracy  
✅ **Automatic failure diagnosis** – Classifies issues as retrieval, prompting, or ranking failures  
✅ **Online and offline evaluation** – Both real-time and batch evaluation modes  
✅ **Prompt versioning** – A/B test prompt templates with side-by-side metrics  
✅ **Reranking support** – Hybrid or lexical reranking with base score tracking  
✅ **Production patterns** – Async jobs, deterministic for demos, ready for real models  
✅ **Deployment flexibility** – Local Docker Compose + Vercel demo  

## What This Demonstrates for AI Platform Engineering

Building RAG systems is table stakes now. **What's hard** — and valuable — is:

- **Measuring quality systematically** across thousands of queries, not cherry-picked examples
- **Diagnosing failures at scale** to know whether to fix retrieval, prompting, or ranking
- **Shipping changes with confidence** using offline evals before touching production
- **Making AI systems observable** like traditional software (traces, metrics, alerts)

This project shows platform thinking:
- **Instrumentation from day one** – every query traced, every metric captured
- **Separation of concerns** – Rails for orchestration, Python for compute, Postgres for analytics
- **Production-minded patterns** – deterministic for demos but ready to swap in real models
- **Deployment options** – local development + shareable Vercel demo

## What's Next (Production Considerations)

While this is a demonstration project, here's what you'd add for production use:

**User feedback loop:**
- Thumbs up/down buttons on answers
- Correlate automated metrics with human judgments
- Use feedback to refine eval metrics

**Cost and performance tracking:**
- Track token usage and API costs per query
- Monitor p95/p99 latency across different query types
- Set cost budgets and alerts

**Advanced retrieval metrics:**
- MRR (Mean Reciprocal Rank), NDCG (Normalized Discounted Cumulative Gain)
- Hybrid search scoring with BM25 + semantic
- Query intent classification for dynamic retrieval strategies

**Real LLM integration:**
- Swap deterministic generation for OpenAI/Anthropic/etc.
- Add streaming response support
- Implement token counting and cost tracking
- Add LLM-as-judge with chain-of-thought reasoning

**Observability integration:**
- Export metrics to DataDog, Prometheus, or similar
- Set up alerts on quality degradation (e.g., faithfulness drops below 0.8)
- Integration with LangSmith, Weights & Biases, or Arize

**Multi-tenancy and scale:**
- Tenant isolation for multi-customer deployments
- ClickHouse or similar for >1M traces/day
- Background job queuing with Redis + Sidekiq
- Caching layer (Redis) for frequently accessed chunks

## License

MIT

## Contact

Questions or feedback? Open an issue or reach out at [your-email@example.com]
