class PythonClient
  class Error < StandardError; end

  def initialize
    @conn = Faraday.new(url: ENV.fetch("PYTHON_SERVICE_URL", "http://python:8000")) do |f|
      f.request :retry, max: 2, interval: 0.05, backoff_factor: 2
      f.request :json
      f.response :json, parser_options: { symbolize_names: false }
      f.options.timeout = ENV.fetch("PYTHON_SERVICE_TIMEOUT", 8).to_i
      f.options.open_timeout = 2
      f.adapter Faraday.default_adapter
    end
  end

  def chunk(document:, chunk_size: 500, overlap: 60)
    post("/chunk", { document: document, chunk_size: chunk_size, overlap: overlap })
  end

  def embed(text:)
    post("/embed", { text: text })
  end

  def index(chunks:)
    post("/index", { chunks: chunks })
  end

  def retrieve(query:, top_k: 5, rerank: true, rerank_method: "hybrid")
    post("/retrieve", { query: query, top_k: top_k, rerank: rerank, rerank_method: rerank_method })
  end

  def generate(query:, contexts:, model_name: "stub-rag-1", prompt_version: "v1", prompt_template: nil)
    post("/generate", {
      query: query,
      contexts: contexts,
      model_name: model_name,
      prompt_version: prompt_version,
      prompt_template: prompt_template
    })
  end

  def eval_online(payload)
    post("/eval/online", payload)
  end

  def eval_offline(payload)
    post("/eval/offline", payload)
  end

  private

  def post(path, payload)
    response = @conn.post(path, payload)
    response.body
  rescue Faraday::Error => e
    raise Error, "#{path} failed: #{e.message}"
  end
end
