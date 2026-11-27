class Tag < ApplicationRecord
  KEBAB_CASE = /\A[a-z0-9]+(-[a-z0-9]+)*\z/

  belongs_to :user
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: { scope: :user_id },
                   format: { with: KEBAB_CASE, message: "must be lowercase kebab-case" }
  before_validation { self.description = description.strip if description.is_a?(String) }

  validates :description, presence: true,
                          format: { without: /[\r\n]/, message: "must be a single line" }
end
