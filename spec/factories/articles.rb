FactoryBot.define do
  factory :article do
    user
    sequence(:url) { |n| "https://example.com/post-#{n}" }

    trait :ready do
      status { :ready }
      title { "A title" }
    end

    trait :failed do
      status { :failed }
      failure_reason { "Extraction failed" }
    end
  end
end
