FactoryBot.define do
  factory :tag do
    user
    sequence(:name) { |n| "tag-#{n}" }
    description { "A short description" }
  end
end
