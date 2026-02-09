class Document < ApplicationRecord
  has_many :chunks, dependent: :destroy

  validates :title, :source, :body, presence: true
end
