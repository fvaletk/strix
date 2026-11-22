FactoryBot.define do
  factory :chunk do
    article
    sequence(:position)
    content { "Some chunk content." }
    word_count { 3 }
    embedding { Array.new(1536) { 0.01 } }
  end
end
