class RagPipeline
  TOP_K = 5
  MODEL_NAME = "stub-rag-1"
  RERANK_ENABLED = ENV.fetch("RERANK_ENABLED", "true").to_s.casecmp("true").zero?
  RERANK_METHOD = ENV.fetch("RERANK_METHOD", "hybrid")
  DEFAULT_PROMPT_TEXT = "Answer only from retrieved context and cite chunk ids used."

  PromptConfig = Struct.new(:name, :version, :template, keyword_init: true)

  def initialize(client: PythonClient.new)
    @client = client
  end

  def ingest_document(title:, source:, body:)
    raise ArgumentError, "Document body cannot be blank" if body.blank?

    chunk_payload = @client.chunk(document: body)
    chunk_texts = Array(chunk_payload["chunks"])

    raise PythonClient::Error, "Chunking returned no chunks" if chunk_texts.empty?

    document = nil
    index_rows = []

    ApplicationRecord.transaction do
      document = Document.create!(title: title, source: source, body: body)
      chunk_texts.each_with_index do |chunk_text, idx|
        embedding = @client.embed(text: chunk_text).fetch("embedding")
        chunk = document.chunks.create!(
          content: chunk_text,
          chunk_index: idx,
          embedding: embedding
        )
        index_rows << {
          chunk_id: chunk.id,
          document_id: document.id,
          content: chunk.content,
          embedding: embedding
        }
      end
    end

    @client.index(chunks: index_rows)
    document
  end

  def run_query(query_text:, prompt_template_id: nil)
    raise ArgumentError, "Query text cannot be blank" if query_text.blank?

    prompt_template = resolve_prompt_template(prompt_template_id)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    trace = QueryTrace.create!(query_text: query_text)

    retrieval_payload = @client.retrieve(
      query: query_text,
      top_k: TOP_K,
      rerank: RERANK_ENABLED,
      rerank_method: RERANK_METHOD
    )
    retrieval_rows = Array(retrieval_payload["results"])

    retrieval_rows.each_with_index do |row, idx|
      chunk = Chunk.find_by(id: row["chunk_id"])
      next unless chunk

      trace.retrieval_results.create!(
        chunk: chunk,
        rank: row["rank"] || (idx + 1),
        score: (row["rerank_score"] || row["score"] || 0.0).to_f,
        base_score: (row["base_score"] || row["score"] || 0.0).to_f
      )
    end

    contexts = trace.retrieval_results.includes(:chunk).order(:rank).map do |result|
      { chunk_id: result.chunk_id, content: result.chunk.content }
    end

    generation = @client.generate(
      query: query_text,
      contexts: contexts,
      model_name: MODEL_NAME,
      prompt_version: prompt_template.version,
      prompt_template: prompt_template.template
    )

    latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0).round(2)

    trace.create_model_response!(
      model_name: generation["model_name"] || MODEL_NAME,
      prompt_version: generation["prompt_version"] || prompt_template.version,
      response_text: generation["answer"],
      cited_chunk_ids: Array(generation["cited_chunk_ids"]).map(&:to_i),
      latency_ms: latency_ms
    )

    run_online_eval!(trace, latency_ms, retrieval_rows)

    trace
  end

  def run_offline_eval!
    started_at = Time.current
    run = EvalRun.create!(kind: "offline", started_at: started_at, notes: "Seeded evaluation dataset")

    dataset = EvalQuestion.ordered.map do |q|
      {
        question: q.question_text,
        expected_answer: q.expected_answer,
        gold_chunk_ids: q.gold_chunk_ids
      }
    end

    response = @client.eval_offline(dataset: dataset, top_k: TOP_K)
    aggregate = response["aggregate"] || {}

    aggregate.each do |name, value|
      run.eval_metrics.create!(name: name, value_numeric: value.to_f)
    end

    run.update!(finished_at: Time.current, notes: "Evaluated #{dataset.size} questions")
    run
  rescue StandardError => e
    run&.update!(finished_at: Time.current, notes: "Failed: #{e.message}")
    raise
  end

  private

  def resolve_prompt_template(prompt_template_id)
    template = if prompt_template_id.present?
      PromptTemplate.find_by(id: prompt_template_id)
    else
      PromptTemplate.active_for("rag_default") || PromptTemplate.order(created_at: :desc).first
    end

    template || PromptConfig.new(name: "rag_default", version: "v1", template: DEFAULT_PROMPT_TEXT)
  end

  def run_online_eval!(trace, latency_ms, retrieval_rows)
    started_at = Time.current
    eval_run = EvalRun.create!(kind: "online", started_at: started_at, notes: "Online trace evaluation")

    eval_question = EvalQuestion.find_match(trace.query_text)
    ordered_results = trace.retrieval_results.includes(:chunk).order(:rank)
    base_ids = retrieval_rows
      .sort_by { |row| row["base_rank"].to_i.zero? ? 9999 : row["base_rank"].to_i }
      .map { |row| row["chunk_id"].to_i }
      .uniq

    online_payload = {
      query: trace.query_text,
      response_text: trace.model_response.response_text,
      expected_answer: eval_question&.expected_answer,
      gold_chunk_ids: eval_question&.gold_chunk_ids || [],
      retrieved_chunk_ids: ordered_results.pluck(:chunk_id),
      base_retrieved_chunk_ids: base_ids,
      cited_chunk_ids: trace.model_response.cited_chunk_ids,
      retrieved_chunks: ordered_results.map { |r| { chunk_id: r.chunk_id, content: r.chunk.content } },
      latency_ms: latency_ms
    }

    response = @client.eval_online(online_payload)
    metrics = response["metrics"] || {}

    metrics.each do |name, value|
      eval_run.eval_metrics.create!(
        query_trace: trace,
        name: name,
        value_numeric: value.to_f
      )
    end

    eval_run.update!(finished_at: Time.current)
  rescue StandardError => e
    eval_run&.update!(finished_at: Time.current, notes: "Failed: #{e.message}")
    raise
  end
end
