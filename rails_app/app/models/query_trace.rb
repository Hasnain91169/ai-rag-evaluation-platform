class QueryTrace < ApplicationRecord
  has_many :retrieval_results, dependent: :destroy
  has_one :model_response, dependent: :destroy
  has_many :eval_metrics, dependent: :nullify

  validates :query_text, presence: true

  def latest_metric_value(name)
    eval_metrics.where(name: name).order(created_at: :desc).pick(:value_numeric)
  end

  def diagnosis_tag
    hit_rate = latest_metric_value("retrieval_hit_rate")
    faithfulness = latest_metric_value("faithfulness")
    attribution = latest_metric_value("attribution_score")
    base_hit_rate = latest_metric_value("base_retrieval_hit_rate")

    return "ok" if hit_rate.nil? || faithfulness.nil?

    if base_hit_rate.to_f >= 0.5 && hit_rate < 0.5
      "ranking_issue"
    elsif hit_rate < 0.5 && faithfulness < 0.5
      "retrieval_issue"
    elsif hit_rate >= 0.5 && [faithfulness, attribution].compact.min < 0.5
      "prompting_issue"
    else
      "ok"
    end
  end
end
