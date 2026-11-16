FactoryBot.define do
  factory :llm_call do
    purpose { :summary }
    model { "gemini-3.5-flash-lite" }
    status { :success }
    input_tokens { 10 }
    output_tokens { 5 }
    thinking_tokens { 2 }
    latency_ms { 120 }

    trait :failed do
      status { :error }
      error_message { "boom" }
    end
  end
end
