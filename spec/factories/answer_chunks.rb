FactoryBot.define do
  factory :answer_chunk do
    answer
    chunk
    similarity { 0.9 }
    sequence(:rank) { |n| n }
    cited { false }

    trait :cited do
      cited { true }
    end
  end
end
