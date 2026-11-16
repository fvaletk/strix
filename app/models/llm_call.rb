class LlmCall < ApplicationRecord
  belongs_to :subject, polymorphic: true, optional: true

  enum :purpose, { summary: 0, tagging: 1, embedding: 2, answer: 3 }
  enum :status, { success: 0, error: 1 }

  validates :purpose, :model, :status, presence: true
end
