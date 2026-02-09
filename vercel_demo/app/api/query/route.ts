import { NextResponse } from "next/server";

import { classifyFailure, evaluateQuery, generateAnswer, retrieveChunks } from "@/lib/rag";
import { getStoreMode, saveTrace } from "@/lib/store";

export const runtime = "nodejs";

type QueryPayload = {
  query?: string;
};

export async function POST(request: Request): Promise<NextResponse> {
  const payload = (await request.json()) as QueryPayload;
  const query = payload.query?.trim() ?? "";

  if (!query) {
    return NextResponse.json({ error: "query is required" }, { status: 400 });
  }

  const startedAt = performance.now();
  const retrieved = retrieveChunks(query, 5);
  const answer = generateAnswer(query, retrieved);
  const latencyMs = performance.now() - startedAt;

  const metrics = evaluateQuery({
    query,
    answer,
    retrieved,
    latencyMs
  });

  const diagnosis = classifyFailure(metrics);

  const trace = await saveTrace({
    query_text: query,
    response_text: answer,
    model_name: "stub-rag-1",
    prompt_version: "v1",
    latency_ms: metrics.latency_ms,
    metrics,
    diagnosis,
    retrieval: retrieved
  });

  const mode = await getStoreMode();

  return NextResponse.json({ trace, mode });
}
