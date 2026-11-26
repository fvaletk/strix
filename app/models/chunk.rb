class Chunk < ApplicationRecord
  belongs_to :article
  has_many :answer_chunks, dependent: :destroy

  has_neighbors :embedding

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :article_id }
  validates :content, :word_count, :embedding, presence: true
  validates :word_count, numericality: { only_integer: true, greater_than: 0 }
end
