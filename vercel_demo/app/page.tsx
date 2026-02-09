"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

import { TraceRecord } from "@/lib/types";

const QUICK_QUERIES = [
  "What is the default SSO session timeout?",
  "When are invoices generated?",
  "How often do database backups run?",
  "What is the disaster recovery RTO target?"
];

type TracesResponse = {
  traces: TraceRecord[];
  mode: "postgres" | "memory";
};

function metricValue(value: number): string {
  if (Number.isInteger(value)) {
    return value.toString();
  }
  return value.toFixed(4).replace(/0+$/, "").replace(/\.$/, "");
}

function TraceCard({ trace }: { trace: TraceRecord }): JSX.Element {
  return (
    <article className="card">
      <div className="trace-top">
        <div>
          <div className="meta">Trace {trace.id.slice(0, 8)} | {new Date(trace.created_at).toLocaleString()}</div>
          <h3>{trace.query_text}</h3>
        </div>
        <span className={`badge ${trace.diagnosis}`}>{trace.diagnosis}</span>
      </div>

      <p><strong>Answer:</strong> {trace.response_text}</p>
      <p className="meta">Model: {trace.model_name} | Prompt: {trace.prompt_version} | Latency: {trace.latency_ms} ms</p>

      <section className="metrics">
        <div className="metric">
          <div className="label">Retrieval Hit Rate</div>
          <div className="value">{metricValue(trace.metrics.retrieval_hit_rate)}</div>
        </div>
        <div className="metric">
          <div className="label">Faithfulness</div>
          <div className="value">{metricValue(trace.metrics.faithfulness)}</div>
        </div>
        <div className="metric">
          <div className="label">Hallucination Rate</div>
          <div className="value">{metricValue(trace.metrics.hallucination_rate)}</div>
        </div>
        <div className="metric">
          <div className="label">Answer Accuracy</div>
          <div className="value">{metricValue(trace.metrics.answer_accuracy)}</div>
        </div>
      </section>

      <h4>Retrieved Chunks + Scores</h4>
      {trace.retrieval.map((chunk) => (
        <div key={`${trace.id}-${chunk.chunk_id}`} className="chunk">
          <div className="chunk-header">
            <span>rank #{chunk.rank} | chunk {chunk.chunk_id} | score {chunk.score.toFixed(4)}</span>
            <span>{chunk.document_title}</span>
          </div>
          <div className="mono">{chunk.content}</div>
        </div>
      ))}
    </article>
  );
}

export default function Page(): JSX.Element {
  const [query, setQuery] = useState(QUICK_QUERIES[0]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [mode, setMode] = useState<"postgres" | "memory">("memory");
  const [traces, setTraces] = useState<TraceRecord[]>([]);
  const latestTrace = useMemo(() => traces[0], [traces]);

  useEffect(() => {
    const load = async (): Promise<void> => {
      const response = await fetch("/api/traces", { cache: "no-store" });
      const data = (await response.json()) as TracesResponse;
      setMode(data.mode);
      setTraces(data.traces);
    };

    load().catch(() => {
      setError("Failed to load traces.");
    });
  }, []);

  const runQuery = async (event?: FormEvent): Promise<void> => {
    event?.preventDefault();
    setLoading(true);
    setError("");

    try {
      const response = await fetch("/api/query", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query })
      });

      if (!response.ok) {
        const body = (await response.json()) as { error?: string };
        throw new Error(body.error ?? "Query failed");
      }

      const body = (await response.json()) as { trace: TraceRecord; mode: "postgres" | "memory" };
      setMode(body.mode);
      setTraces((prev) => [body.trace, ...prev].slice(0, 20));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Query failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main>
      <header className="hero">
        <div>
          <h1>RAG Trace Introspection Demo</h1>
          <p>
            Submit a query and inspect full trace-level diagnostics: retrieved chunks, scores,
            evaluation metrics, and failure classification.
          </p>
        </div>
        <div className="mode-pill">Persistence: {mode === "postgres" ? "Vercel Postgres" : "In-memory fallback"}</div>
      </header>

      <div className="grid">
        <section className="card">
          <form onSubmit={runQuery}>
            <label htmlFor="query"><strong>Ask a question</strong></label>
            <div className="query-row">
              <input
                id="query"
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="What is the default SSO session timeout?"
                required
              />
              <button type="submit" disabled={loading}>{loading ? "Running..." : "Run RAG Trace"}</button>
            </div>
          </form>
          <div className="quick-list">
            {QUICK_QUERIES.map((q) => (
              <button
                key={q}
                type="button"
                onClick={() => {
                  setQuery(q);
                }}
              >
                {q}
              </button>
            ))}
          </div>
          {error ? <div className="error">{error}</div> : null}
        </section>

        {latestTrace ? (
          <section>
            <h2>Latest Trace</h2>
            <TraceCard trace={latestTrace} />
          </section>
        ) : null}

        <section>
          <h2>Recent Traces</h2>
          <div className="trace-list">
            {traces.length === 0 ? <div className="card">No traces yet. Submit your first query.</div> : null}
            {traces.slice(0, 8).map((trace) => (
              <TraceCard key={trace.id} trace={trace} />
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}
