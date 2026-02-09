require "rails_helper"

RSpec.describe "QueryTraces", type: :request do
  describe "POST /query_traces" do
    it "creates a query trace via pipeline and redirects" do
      trace = QueryTrace.create!(query_text: "Seed question")

      allow_any_instance_of(RagPipeline).to receive(:run_query).and_return(trace)

      post query_traces_path, params: { query_trace: { query_text: "What is timeout?" } }

      expect(response).to redirect_to(query_trace_path(trace))
    end
  end
end
