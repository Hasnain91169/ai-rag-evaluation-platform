import { EvalQuestion, RetrievedChunk } from "./types";

export const SEEDED_CHUNKS: RetrievedChunk[] = [
  {
    chunk_id: 101,
    document_title: "Auth and Access Guide",
    rank: 0,
    score: 0,
    content: "Single sign-on (SSO) is available on Pro and Enterprise plans. Customers can connect Okta or Azure AD using SAML 2.0."
  },
  {
    chunk_id: 102,
    document_title: "Auth and Access Guide",
    rank: 0,
    score: 0,
    content: "The default SSO session timeout is 8 hours. Admins can lower the timeout to 1 hour for high-security environments."
  },
  {
    chunk_id: 103,
    document_title: "Auth and Access Guide",
    rank: 0,
    score: 0,
    content: "Multi-factor authentication is required for workspace owners and billing admins. Standard members can enable MFA optionally."
  },
  {
    chunk_id: 104,
    document_title: "Auth and Access Guide",
    rank: 0,
    score: 0,
    content: "API access tokens expire after 90 days by default. Rotating tokens every 30 days is recommended by security policy."
  },
  {
    chunk_id: 105,
    document_title: "Auth and Access Guide",
    rank: 0,
    score: 0,
    content: "Audit logs are retained for 365 days on Enterprise. Pro workspaces retain audit logs for 90 days."
  },
  {
    chunk_id: 106,
    document_title: "Billing and Subscription Handbook",
    rank: 0,
    score: 0,
    content: "The Free plan includes up to 3 seats and 5 GB of storage. Pro starts at 20 seats but admins can buy extra seats."
  },
  {
    chunk_id: 107,
    document_title: "Billing and Subscription Handbook",
    rank: 0,
    score: 0,
    content: "Invoices are generated on the first day of each month for annual and monthly subscriptions."
  },
  {
    chunk_id: 108,
    document_title: "Billing and Subscription Handbook",
    rank: 0,
    score: 0,
    content: "If payment fails, the account enters a 7-day grace period before read-only mode is applied."
  },
  {
    chunk_id: 109,
    document_title: "Billing and Subscription Handbook",
    rank: 0,
    score: 0,
    content: "Customers can switch from monthly to annual billing at any time. Credits are prorated automatically."
  },
  {
    chunk_id: 110,
    document_title: "Billing and Subscription Handbook",
    rank: 0,
    score: 0,
    content: "Refund requests are accepted within 14 days of the initial purchase for new annual subscriptions."
  },
  {
    chunk_id: 111,
    document_title: "Reliability and Incident Runbook",
    rank: 0,
    score: 0,
    content: "Severity 1 incidents require initial acknowledgment in 10 minutes and executive paging within 15 minutes."
  },
  {
    chunk_id: 112,
    document_title: "Reliability and Incident Runbook",
    rank: 0,
    score: 0,
    content: "A public status page update must be posted within 20 minutes for customer-facing outages."
  },
  {
    chunk_id: 113,
    document_title: "Reliability and Incident Runbook",
    rank: 0,
    score: 0,
    content: "Postmortems are mandatory for Severity 1 and Severity 2 incidents and must be published within 5 business days."
  },
  {
    chunk_id: 114,
    document_title: "Reliability and Incident Runbook",
    rank: 0,
    score: 0,
    content: "Database backups run every 6 hours with point-in-time recovery enabled. Backup retention is 30 days."
  },
  {
    chunk_id: 115,
    document_title: "Reliability and Incident Runbook",
    rank: 0,
    score: 0,
    content: "Disaster recovery drills are performed quarterly with a target recovery time objective of 60 minutes."
  }
];

export const EVAL_QUESTIONS: EvalQuestion[] = [
  {
    question: "What is the default SSO session timeout?",
    expected_answer: "The default SSO session timeout is 8 hours.",
    gold_chunk_ids: [102]
  },
  {
    question: "Who must use MFA?",
    expected_answer: "Workspace owners and billing admins must use MFA.",
    gold_chunk_ids: [103]
  },
  {
    question: "How long do API access tokens last by default?",
    expected_answer: "API access tokens expire after 90 days by default.",
    gold_chunk_ids: [104]
  },
  {
    question: "How long are Enterprise audit logs retained?",
    expected_answer: "Enterprise audit logs are retained for 365 days.",
    gold_chunk_ids: [105]
  },
  {
    question: "Which identity providers are supported for SSO?",
    expected_answer: "Okta and Azure AD are supported via SAML 2.0.",
    gold_chunk_ids: [101]
  },
  {
    question: "How many seats are included in the Free plan?",
    expected_answer: "The Free plan includes up to 3 seats.",
    gold_chunk_ids: [106]
  },
  {
    question: "When are invoices generated?",
    expected_answer: "Invoices are generated on the first day of each month.",
    gold_chunk_ids: [107]
  },
  {
    question: "How long is the billing grace period after payment failure?",
    expected_answer: "The grace period is 7 days.",
    gold_chunk_ids: [108]
  },
  {
    question: "Can customers switch billing cadence?",
    expected_answer: "Yes, customers can switch from monthly to annual billing at any time.",
    gold_chunk_ids: [109]
  },
  {
    question: "When are refunds accepted for annual subscriptions?",
    expected_answer: "Refund requests are accepted within 14 days of the initial purchase.",
    gold_chunk_ids: [110]
  },
  {
    question: "How fast must Severity 1 incidents be acknowledged?",
    expected_answer: "Severity 1 incidents must be acknowledged in 10 minutes.",
    gold_chunk_ids: [111]
  },
  {
    question: "How quickly should status page updates be posted for outages?",
    expected_answer: "A status page update must be posted within 20 minutes.",
    gold_chunk_ids: [112]
  },
  {
    question: "By when must postmortems be published?",
    expected_answer: "Postmortems must be published within 5 business days.",
    gold_chunk_ids: [113]
  },
  {
    question: "How often do database backups run?",
    expected_answer: "Database backups run every 6 hours.",
    gold_chunk_ids: [114]
  },
  {
    question: "What is the disaster recovery RTO target?",
    expected_answer: "The target recovery time objective is 60 minutes.",
    gold_chunk_ids: [115]
  }
];
