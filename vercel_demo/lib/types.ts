export type DiagnosisTag = "retrieval_issue" | "prompting_issue" | "ok";

export type EvalMetrics = {
  retrieval_hit_rate: number;
  latency_ms: number;
  faithfulness: number;
  hallucination_rate: number;
  answer_accuracy: number;
};

export type RetrievedChunk = {
  chunk_id: number;
  document_title: string;
  content: string;
  rank: number;
  score: number;
};

export type TraceRecord = {
  id: string;
  query_text: string;
  response_text: string;
  model_name: string;
  prompt_version: string;
  latency_ms: number;
  metrics: EvalMetrics;
  diagnosis: DiagnosisTag;
  retrieval: RetrievedChunk[];
  created_at: string;
};

export type EvalQuestion = {
  question: string;
  expected_answer: string;
  gold_chunk_ids: number[];
};
