class Question < ApplicationRecord
  belongs_to :user
  has_one :answer, dependent: :destroy

  validates :text, presence: true
end
