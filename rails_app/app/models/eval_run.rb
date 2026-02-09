class EvalRun < ApplicationRecord
  has_many :eval_metrics, dependent: :destroy

  enum kind: { offline: "offline", online: "online" }

  validates :kind, :started_at, presence: true

  def metric_value(name)
    eval_metrics.where(name: name, query_trace_id: nil).order(created_at: :desc).pick(:value_numeric)
  end
end
