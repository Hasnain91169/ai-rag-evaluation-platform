class EvalQuestion < ApplicationRecord
  validates :question_text, :expected_answer, presence: true

  scope :ordered, -> { order(:id) }

  def self.find_match(query_text)
    find_by("lower(question_text) = ?", query_text.to_s.strip.downcase)
  end
end
