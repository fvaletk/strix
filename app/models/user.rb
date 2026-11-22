class User < ApplicationRecord
  has_many :articles, dependent: :destroy
  has_many :tags, dependent: :destroy

  def self.current = first!
end
