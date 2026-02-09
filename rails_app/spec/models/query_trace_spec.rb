require "rails_helper"

RSpec.describe QueryTrace, type: :model do
  it "labels retrieval issues when retrieval and faithfulness are both low" do
    trace = QueryTrace.create!(query_text: "Example?")
    run = EvalRun.create!(kind: "online", started_at: Time.current)
    EvalMetric.create!(eval_run: run, query_trace: trace, name: "retrieval_hit_rate", value_numeric: 0.1)
    EvalMetric.create!(eval_run: run, query_trace: trace, name: "faithfulness", value_numeric: 0.2)

    expect(trace.diagnosis_tag).to eq("retrieval_issue")
  end

  it "labels ranking issues when base retrieval hit is high but final hit is low" do
    trace = QueryTrace.create!(query_text: "Example?")
    run = EvalRun.create!(kind: "online", started_at: Time.current)
    EvalMetric.create!(eval_run: run, query_trace: trace, name: "base_retrieval_hit_rate", value_numeric: 1.0)
    EvalMetric.create!(eval_run: run, query_trace: trace, name: "retrieval_hit_rate", value_numeric: 0.0)
    EvalMetric.create!(eval_run: run, query_trace: trace, name: "faithfulness", value_numeric: 0.2)

    expect(trace.diagnosis_tag).to eq("ranking_issue")
  end
end
