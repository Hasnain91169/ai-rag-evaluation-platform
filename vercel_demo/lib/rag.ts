import { EVAL_QUESTIONS, SEEDED_CHUNKS } from "./corpus";
import { DiagnosisTag, EvalMetrics, RetrievedChunk } from "./types";

const STOPWORDS = new Set([
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
  "from",
  "it",
  "any",
  "must"
]);

function tokenize(text: string): string[] {
  return (text.toLowerCase().match(/[a-z0-9]+/g) ?? []).filter(Boolean);
}

function hashToken(token: string): number {
  let h = 2166136261;
  for (let i = 0; i < token.length; i += 1) {
    h ^= token.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return Math.abs(h >>> 0);
}

function embedding(text: string, dims = 24): number[] {
  const vec = Array.from({ length: dims }, () => 0);
  tokenize(text).forEach((token) => {
    const bucket = hashToken(token) % dims;
    vec[bucket] += 1;
  });

  const norm = Math.sqrt(vec.reduce((sum, value) => sum + value * value, 0));
  if (norm === 0) {
    return vec;
  }
  return vec.map((v) => v / norm);
}

function cosine(a: number[], b: number[]): number {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) {
    return 0;
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

function overlapScore(answer: string, expected: string): number {
  const answerTokens = new Set(tokenize(answer).filter((t) => !STOPWORDS.has(t)));
  const expectedTokens = new Set(tokenize(expected).filter((t) => !STOPWORDS.has(t)));
  if (expectedTokens.size === 0) {
    return 0;
  }

  let overlap = 0;
  expectedTokens.forEach((token) => {
    if (answerTokens.has(token)) {
      overlap += 1;
    }
  });
  return overlap / expectedTokens.size;
}

function faithfulness(answer: string, contexts: string[]): number {
  const answerTokens = tokenize(answer).filter((t) => !STOPWORDS.has(t));
  if (answerTokens.length === 0) {
    return 1;
  }

  const contextTokens = new Set(
    contexts.flatMap((ctx) => tokenize(ctx).filter((t) => !STOPWORDS.has(t)))
  );

  if (contextTokens.size === 0) {
    return 0;
  }

  let covered = 0;
  answerTokens.forEach((token) => {
    if (contextTokens.has(token)) {
      covered += 1;
    }
  });
  return covered / answerTokens.length;
}

export function retrieveChunks(query: string, topK = 5): RetrievedChunk[] {
  const q = embedding(query);
  return SEEDED_CHUNKS
    .map((chunk) => {
      const score = cosine(q, embedding(chunk.content));
      return { ...chunk, score };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, topK)
    .map((chunk, idx) => ({ ...chunk, rank: idx + 1, score: Number(chunk.score.toFixed(4)) }));
}

export function generateAnswer(query: string, retrieved: RetrievedChunk[]): string {
  if (retrieved.length === 0) {
    return "I could not find relevant context for this query.";
  }

  const qTokens = new Set(tokenize(query));
  let best = retrieved[0];
  let bestOverlap = -1;

  retrieved.forEach((chunk) => {
    const overlap = tokenize(chunk.content).filter((t) => qTokens.has(t)).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = chunk;
    }
  });

  const summary = best.content.split(". ")[0].trim();
  return `Answer (from chunk ${best.chunk_id}): ${summary}.`;
}

export function classifyFailure(metrics: EvalMetrics): DiagnosisTag {
  if (metrics.retrieval_hit_rate < 0.5 && metrics.faithfulness < 0.5) {
    return "retrieval_issue";
  }
  if (metrics.retrieval_hit_rate >= 0.5 && metrics.faithfulness < 0.5) {
    return "prompting_issue";
  }
  return "ok";
}

export function evaluateQuery(params: {
  query: string;
  answer: string;
  retrieved: RetrievedChunk[];
  latencyMs: number;
}): EvalMetrics {
  const normalizedQuery = params.query.trim().toLowerCase();
  const knownQuestion = EVAL_QUESTIONS.find(
    (q) => q.question.trim().toLowerCase() === normalizedQuery
  );

  const retrievedIds = new Set(params.retrieved.map((r) => r.chunk_id));
  const hitRate = knownQuestion
    ? knownQuestion.gold_chunk_ids.some((id) => retrievedIds.has(id))
      ? 1
      : 0
    : params.retrieved[0]?.score && params.retrieved[0].score > 0.45
      ? 1
      : 0;

  const faith = faithfulness(
    params.answer,
    params.retrieved.map((r) => r.content)
  );

  const answerAccuracy = knownQuestion
    ? overlapScore(params.answer, knownQuestion.expected_answer)
    : faith;

  return {
    retrieval_hit_rate: Number(hitRate.toFixed(4)),
    latency_ms: Number(params.latencyMs.toFixed(2)),
    faithfulness: Number(faith.toFixed(4)),
    hallucination_rate: Number((1 - faith).toFixed(4)),
    answer_accuracy: Number(answerAccuracy.toFixed(4))
  };
}
