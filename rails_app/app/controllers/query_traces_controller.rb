class QueryTracesController < ApplicationController
  def index
    @query_traces = QueryTrace.includes(:model_response, retrieval_results: :chunk).order(created_at: :desc).limit(50)
  end

  def show
    @query_trace = QueryTrace.includes(:model_response, :eval_metrics, retrieval_results: :chunk).find(params[:id])
    @diagnosis = @query_trace.diagnosis_tag
  end

  def new
    @query_trace = QueryTrace.new
    @prompt_templates = PromptTemplate.order(:name, :version)
    @active_prompt_template_id = @prompt_templates.find(&:active)&.id
  end

  def create
    @query_trace = RagPipeline.new.run_query(
      query_text: query_params[:query_text],
      prompt_template_id: query_params[:prompt_template_id]
    )
    redirect_to query_trace_path(@query_trace), notice: "RAG query completed."
  rescue StandardError => e
    render_service_error(e)
  end

  private

  def query_params
    params.require(:query_trace).permit(:query_text, :prompt_template_id)
  end
end
