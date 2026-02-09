class PromptTemplate < ApplicationRecord
  before_save :deactivate_other_versions, if: :active?

  validates :name, :version, :template, presence: true
  validates :version, uniqueness: { scope: :name }

  scope :active_first, -> { order(active: :desc, created_at: :desc) }

  def self.active_for(name = "rag_default")
    where(name: name, active: true).order(created_at: :desc).first
  end

  private

  def deactivate_other_versions
    PromptTemplate.where(name: name).where.not(id: id).update_all(active: false)
  end
end
