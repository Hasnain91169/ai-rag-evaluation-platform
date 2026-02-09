class DashboardController < ApplicationController
  def index
    @offline_runs = EvalRun.offline.includes(:eval_metrics).order(started_at: :desc).limit(12)
    @trend_rows = trend_rows(@offline_runs.reverse)
    @weekly_rows = weekly_rows
    @prompt_version_rows = prompt_version_rows
    @recent_traces = QueryTrace.includes(:model_response, :eval_metrics, retrieval_results: :chunk)
                              .order(created_at: :desc)
                              .limit(10)
  end

  private

  def trend_rows(runs)
    runs.map do |run|
      {
        run_id: run.id,
        started_at: run.started_at,
        accuracy: run.metric_value("answer_accuracy"),
        hit_rate: run.metric_value("retrieval_hit_rate"),
        hallucination_rate: run.metric_value("hallucination_rate"),
        latency_ms: run.metric_value("latency_ms")
      }
    end
  end

  def weekly_rows
    runs = EvalRun.offline.includes(:eval_metrics).where("started_at >= ?", 8.weeks.ago).order(:started_at)
    grouped = runs.group_by { |run| run.started_at.to_date.beginning_of_week }

    grouped.map do |week, week_runs|
      {
        week_start: week,
        accuracy: avg_metric(week_runs, "answer_accuracy"),
        hit_rate: avg_metric(week_runs, "retrieval_hit_rate"),
        hallucination_rate: avg_metric(week_runs, "hallucination_rate"),
        latency_ms: avg_metric(week_runs, "latency_ms")
      }
    end
  end

  def prompt_version_rows
    responses = ModelResponse.includes(query_trace: :eval_metrics).order(created_at: :desc).limit(300)
    grouped = responses.group_by(&:prompt_version)

    grouped.map do |version, version_responses|
      faithfulness_vals = version_responses.filter_map { |r| r.query_trace.latest_metric_value("faithfulness") }
      attribution_vals = version_responses.filter_map { |r| r.query_trace.latest_metric_value("attribution_score") }
      {
        prompt_version: version,
        traces: version_responses.size,
        avg_latency_ms: version_responses.sum(&:latency_ms) / version_responses.size,
        avg_faithfulness: average(faithfulness_vals),
        avg_attribution: average(attribution_vals)
      }
    end.sort_by { |row| row[:prompt_version].to_s }
  end

  def avg_metric(runs, metric_name)
    vals = runs.map { |run| run.metric_value(metric_name) }.compact
    average(vals)
  end

  def average(values)
    return nil if values.empty?

    values.sum / values.size
  end
end
