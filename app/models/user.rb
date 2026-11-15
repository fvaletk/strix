class User < ApplicationRecord
  has_many :articles, dependent: :destroy

  def self.current = first!
end
