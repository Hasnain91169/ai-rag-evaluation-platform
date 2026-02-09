class Chunk < ApplicationRecord
  belongs_to :document
  has_many :retrieval_results, dependent: :destroy

  validates :content, :chunk_index, presence: true
end
