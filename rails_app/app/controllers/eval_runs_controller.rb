class EvalRunsController < ApplicationController
  def index
    @eval_runs = EvalRun.includes(:eval_metrics).order(started_at: :desc).limit(50)
  end

  def create_offline
    run = RagPipeline.new.run_offline_eval!
    redirect_to eval_runs_path, notice: "Offline eval run ##{run.id} complete."
  rescue StandardError => e
    render_service_error(e)
  end
end
