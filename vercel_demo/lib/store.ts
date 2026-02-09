import { sql } from "@vercel/postgres";

import { TraceRecord } from "./types";

type Mode = "postgres" | "memory";

type TraceInput = Omit<TraceRecord, "id" | "created_at">;

type MemoryState = {
  traces: TraceRecord[];
};

declare global {
  var __ragEvalMemoryState: MemoryState | undefined;
}

function memoryState(): MemoryState {
  if (!global.__ragEvalMemoryState) {
    global.__ragEvalMemoryState = { traces: [] };
  }
  return global.__ragEvalMemoryState;
}

function usePostgres(): boolean {
  return Boolean(process.env.POSTGRES_URL);
}

async function ensureSchema(): Promise<void> {
  if (!usePostgres()) {
    return;
  }

  await sql`
    CREATE TABLE IF NOT EXISTS demo_traces (
      id TEXT PRIMARY KEY,
      query_text TEXT NOT NULL,
      response_text TEXT NOT NULL,
      model_name TEXT NOT NULL,
      prompt_version TEXT NOT NULL,
      latency_ms DOUBLE PRECISION NOT NULL,
      metrics JSONB NOT NULL,
      diagnosis TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS demo_retrieval_results (
      id BIGSERIAL PRIMARY KEY,
      trace_id TEXT NOT NULL REFERENCES demo_traces(id) ON DELETE CASCADE,
      chunk_id BIGINT NOT NULL,
      document_title TEXT NOT NULL,
      content TEXT NOT NULL,
      rank INTEGER NOT NULL,
      score DOUBLE PRECISION NOT NULL
    )
  `;
}

export async function getStoreMode(): Promise<Mode> {
  return usePostgres() ? "postgres" : "memory";
}

export async function saveTrace(input: TraceInput): Promise<TraceRecord> {
  const id = crypto.randomUUID();
  const nowIso = new Date().toISOString();
  const trace: TraceRecord = {
    id,
    created_at: nowIso,
    ...input
  };

  if (!usePostgres()) {
    const state = memoryState();
    state.traces.unshift(trace);
    state.traces = state.traces.slice(0, 50);
    return trace;
  }

  await ensureSchema();
  await sql`
    INSERT INTO demo_traces (id, query_text, response_text, model_name, prompt_version, latency_ms, metrics, diagnosis, created_at)
    VALUES (${trace.id}, ${trace.query_text}, ${trace.response_text}, ${trace.model_name}, ${trace.prompt_version}, ${trace.latency_ms}, ${JSON.stringify(trace.metrics)}::jsonb, ${trace.diagnosis}, ${trace.created_at}::timestamptz)
  `;

  for (const row of trace.retrieval) {
    await sql`
      INSERT INTO demo_retrieval_results (trace_id, chunk_id, document_title, content, rank, score)
      VALUES (${trace.id}, ${row.chunk_id}, ${row.document_title}, ${row.content}, ${row.rank}, ${row.score})
    `;
  }

  return trace;
}

export async function listTraces(limit = 20): Promise<TraceRecord[]> {
  if (!usePostgres()) {
    return memoryState().traces.slice(0, limit);
  }

  await ensureSchema();

  const rows = await sql`
    SELECT
      t.id,
      t.query_text,
      t.response_text,
      t.model_name,
      t.prompt_version,
      t.latency_ms,
      t.metrics,
      t.diagnosis,
      t.created_at,
      COALESCE(
        json_agg(
          json_build_object(
            'chunk_id', r.chunk_id,
            'document_title', r.document_title,
            'content', r.content,
            'rank', r.rank,
            'score', r.score
          )
          ORDER BY r.rank
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'::json
      ) AS retrieval
    FROM demo_traces t
    LEFT JOIN demo_retrieval_results r ON r.trace_id = t.id
    GROUP BY t.id, t.query_text, t.response_text, t.model_name, t.prompt_version, t.latency_ms, t.metrics, t.diagnosis, t.created_at
    ORDER BY t.created_at DESC
    LIMIT ${limit}
  `;

  const parseJson = <T>(value: unknown): T => {
    if (typeof value === "string") {
      return JSON.parse(value) as T;
    }
    return value as T;
  };

  return rows.rows.map((row) => ({
    id: String(row.id),
    query_text: String(row.query_text),
    response_text: String(row.response_text),
    model_name: String(row.model_name),
    prompt_version: String(row.prompt_version),
    latency_ms: Number(row.latency_ms),
    metrics: parseJson<TraceRecord["metrics"]>(row.metrics),
    diagnosis: String(row.diagnosis) as TraceRecord["diagnosis"],
    created_at: new Date(row.created_at).toISOString(),
    retrieval: parseJson<TraceRecord["retrieval"]>(row.retrieval)
  })) as TraceRecord[];
}
