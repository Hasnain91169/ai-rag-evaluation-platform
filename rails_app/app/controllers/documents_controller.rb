class DocumentsController < ApplicationController
  def index
    @documents = Document.order(created_at: :desc).includes(:chunks)
  end

  def show
    @document = Document.includes(:chunks).find(params[:id])
  end

  def new
    @document = Document.new
  end

  def create
    @document = RagPipeline.new.ingest_document(
      title: document_params[:title],
      source: document_params[:source],
      body: document_params[:body]
    )

    redirect_to document_path(@document), notice: "Document ingested and indexed."
  rescue StandardError => e
    render_service_error(e)
  end

  private

  def document_params
    params.require(:document).permit(:title, :source, :body)
  end
end
