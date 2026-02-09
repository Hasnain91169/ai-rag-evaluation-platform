# Vercel Demo: RAG Trace Introspection

This is a Vercel-native demo that highlights:
- query submission
- retrieved chunks with scores
- eval metrics per trace
- failure classification (`retrieval_issue`, `prompting_issue`, `ok`)

It is deterministic and does not require paid model APIs.

## Stack
- Next.js 14 (App Router)
- Vercel Serverless API routes
- Optional Vercel Postgres persistence
- In-memory fallback when Postgres is not configured

## Local run

```bash
cd vercel_demo
npm install
npm run dev
```

Open http://localhost:3000.

## Deploy to Vercel

1. Push this repo to GitHub.
2. In Vercel, import the repo.
3. Set **Root Directory** to `vercel_demo`.
4. Deploy.

### Optional: enable persistent traces (recommended)

1. In Vercel project, go to **Storage** and create **Postgres**.
2. Vercel injects `POSTGRES_URL` automatically.
3. Redeploy.

The app auto-creates demo tables on first request:
- `demo_traces`
- `demo_retrieval_results`

If `POSTGRES_URL` is missing, the demo still works in memory.

## API endpoints
- `POST /api/query` - runs retrieval, generation, eval, and saves trace
- `GET /api/traces` - recent traces
- `GET /api/health` - health + persistence mode

## Demo script for non-engineers

1. Open the app URL.
2. Ask: `What is the default SSO session timeout?`
3. Show:
- top retrieved chunks and scores
- generated answer
- eval metrics (`retrieval_hit_rate`, `faithfulness`, `hallucination_rate`, `answer_accuracy`, `latency_ms`)
- failure classification badge
4. Ask an intentionally vague/off-domain question to show failure mode and diagnosis behavior.

## Deterministic behavior
- Retrieval uses deterministic hashed embeddings and cosine similarity.
- Generation is a deterministic context-based stub.
- Eval metrics are deterministic token-overlap/coverage proxies.
