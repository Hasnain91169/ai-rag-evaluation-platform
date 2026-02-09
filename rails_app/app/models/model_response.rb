class ModelResponse < ApplicationRecord
  belongs_to :query_trace

  validates :model_name, :prompt_version, :response_text, :latency_ms, presence: true

  def cited_chunk_ids
    Array(super).map(&:to_i)
  end
end
