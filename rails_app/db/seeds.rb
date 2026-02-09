require "digest"

puts "Resetting demo data..."

[EvalMetric, EvalRun, ModelResponse, RetrievalResult, QueryTrace, EvalQuestion, Chunk, Document, PromptTemplate].each(&:delete_all)

# Deterministic embedding for seed persistence; Python service can overwrite/use for retrieval index.
def seed_embedding(text, dims: 16)
  tokens = text.downcase.scan(/[a-z0-9]+/)
  vec = Array.new(dims, 0.0)
  tokens.each do |token|
    digest = Digest::SHA256.hexdigest(token)
    dims.times do |i|
      vec[i] += digest[(i * 2)...(i * 2 + 2)].to_i(16)
    end
  end
  norm = Math.sqrt(vec.sum { |v| v * v })
  return vec if norm.zero?

  vec.map { |v| (v / norm).round(8) }
end

PromptTemplate.create!(
  name: "rag_default",
  version: "v1",
  template: "Answer strictly from provided chunks. Keep answer concise and include chunk citations.",
  active: true
)
PromptTemplate.create!(
  name: "rag_default",
  version: "v2",
  template: "You are a support assistant. Prefer exact policy values and cite only chunk ids used.",
  active: false
)

doc_defs = [
  {
    title: "Auth and Access Guide",
    source: "product-docs/auth",
    chunks: [
      "Single sign-on (SSO) is available on Pro and Enterprise plans. Customers can connect Okta or Azure AD using SAML 2.0.",
      "The default SSO session timeout is 8 hours. Admins can lower the timeout to 1 hour for high-security environments.",
      "Multi-factor authentication is required for workspace owners and billing admins. Standard members can enable MFA optionally.",
      "API access tokens expire after 90 days by default. Rotating tokens every 30 days is recommended by security policy.",
      "Audit logs are retained for 365 days on Enterprise. Pro workspaces retain audit logs for 90 days."
    ]
  },
  {
    title: "Billing and Subscription Handbook",
    source: "product-docs/billing",
    chunks: [
      "The Free plan includes up to 3 seats and 5 GB of storage. Pro starts at 20 seats but admins can buy extra seats.",
      "Invoices are generated on the first day of each month for annual and monthly subscriptions.",
      "If payment fails, the account enters a 7-day grace period before read-only mode is applied.",
      "Customers can switch from monthly to annual billing at any time. Credits are prorated automatically.",
      "Refund requests are accepted within 14 days of the initial purchase for new annual subscriptions."
    ]
  },
  {
    title: "Reliability and Incident Runbook",
    source: "product-docs/reliability",
    chunks: [
      "Severity 1 incidents require initial acknowledgment in 10 minutes and executive paging within 15 minutes.",
      "A public status page update must be posted within 20 minutes for customer-facing outages.",
      "Postmortems are mandatory for Severity 1 and Severity 2 incidents and must be published within 5 business days.",
      "Database backups run every 6 hours with point-in-time recovery enabled. Backup retention is 30 days.",
      "Disaster recovery drills are performed quarterly with a target recovery time objective of 60 minutes."
    ]
  }
]

ActiveRecord::Base.transaction do
  doc_defs.each do |doc_def|
    document = Document.create!(
      title: doc_def[:title],
      source: doc_def[:source],
      body: doc_def[:chunks].join("\n\n")
    )

    doc_def[:chunks].each_with_index do |chunk_text, idx|
      document.chunks.create!(
        chunk_index: idx,
        content: chunk_text,
        embedding: seed_embedding(chunk_text)
      )
    end
  end
end

questions = [
  ["What is the default SSO session timeout?", "The default SSO session timeout is 8 hours.", "default SSO session timeout is 8 hours"],
  ["Who must use MFA?", "Workspace owners and billing admins must use MFA.", "Multi-factor authentication is required for workspace owners and billing admins"],
  ["How long do API access tokens last by default?", "API access tokens expire after 90 days by default.", "API access tokens expire after 90 days"],
  ["How long are Enterprise audit logs retained?", "Enterprise audit logs are retained for 365 days.", "Audit logs are retained for 365 days"],
  ["Which identity providers are supported for SSO?", "Okta and Azure AD are supported via SAML 2.0.", "connect Okta or Azure AD"],

  ["How many seats are included in the Free plan?", "The Free plan includes up to 3 seats.", "Free plan includes up to 3 seats"],
  ["When are invoices generated?", "Invoices are generated on the first day of each month.", "Invoices are generated on the first day of each month"],
  ["How long is the billing grace period after payment failure?", "The grace period is 7 days.", "7-day grace period"],
  ["Can customers switch billing cadence?", "Yes, customers can switch from monthly to annual billing at any time.", "switch from monthly to annual billing at any time"],
  ["When are refunds accepted for annual subscriptions?", "Refund requests are accepted within 14 days of the initial purchase.", "Refund requests are accepted within 14 days"],

  ["How fast must Severity 1 incidents be acknowledged?", "Severity 1 incidents must be acknowledged in 10 minutes.", "acknowledgment in 10 minutes"],
  ["How quickly should status page updates be posted for outages?", "A status page update must be posted within 20 minutes.", "status page update must be posted within 20 minutes"],
  ["By when must postmortems be published?", "Postmortems must be published within 5 business days.", "published within 5 business days"],
  ["How often do database backups run?", "Database backups run every 6 hours.", "Database backups run every 6 hours"],
  ["What is the disaster recovery RTO target?", "The target recovery time objective is 60 minutes.", "recovery time objective of 60 minutes"]
]

questions.each do |question_text, expected_answer, phrase|
  chunk_id = Chunk.where("content ILIKE ?", "%#{phrase}%").pick(:id)
  EvalQuestion.create!(
    question_text: question_text,
    expected_answer: expected_answer,
    gold_chunk_ids: chunk_id ? [chunk_id] : []
  )
end

begin
  client = PythonClient.new
  index_rows = Chunk.find_each.map do |chunk|
    {
      chunk_id: chunk.id,
      document_id: chunk.document_id,
      content: chunk.content,
      embedding: chunk.embedding
    }
  end
  client.index(chunks: index_rows)
  puts "Indexed #{index_rows.size} chunks into Python service."
rescue StandardError => e
  puts "Skipping Python index during seed: #{e.message}"
end

puts "Seeded #{Document.count} documents, #{Chunk.count} chunks, #{EvalQuestion.count} eval questions, #{PromptTemplate.count} prompt templates."
