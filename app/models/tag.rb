class Tag < ApplicationRecord
  KEBAB_CASE = /\A[a-z0-9]+(-[a-z0-9]+)*\z/

  belongs_to :user
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: { scope: :user_id },
                   format: { with: KEBAB_CASE, message: "must be lowercase kebab-case" }
  validates :description, presence: true
end
