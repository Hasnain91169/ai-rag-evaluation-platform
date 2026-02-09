class RetrievalResult < ApplicationRecord
  belongs_to :query_trace
  belongs_to :chunk

  validates :rank, :score, :base_score, presence: true
end
