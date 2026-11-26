class User < ApplicationRecord
  has_many :articles, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :questions, dependent: :destroy

  def self.current = first!
end
