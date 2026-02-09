class EvalMetric < ApplicationRecord
  belongs_to :eval_run
  belongs_to :query_trace, optional: true

  validates :name, :value_numeric, presence: true
end
