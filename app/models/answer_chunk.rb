class AnswerChunk < ApplicationRecord
  belongs_to :answer
  belongs_to :chunk

  validates :similarity, presence: true, numericality: true
  validates :rank, presence: true, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :answer_id }
end
