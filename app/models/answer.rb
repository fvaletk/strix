class Answer < ApplicationRecord
  belongs_to :question
  has_many :answer_chunks, -> { order(:rank) }, dependent: :destroy, inverse_of: :answer
  has_many :chunks, through: :answer_chunks

  validates :text, presence: true

  def cited_articles
    Article.where(id: answer_chunks.where(cited: true).joins(:chunk).select("chunks.article_id")).order(:id)
  end
end
