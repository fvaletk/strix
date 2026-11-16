require "rails_helper"

RSpec.describe LlmCall, type: :model do
  subject { build(:llm_call) }

  it { is_expected.to belong_to(:subject).optional }
  it { is_expected.to validate_presence_of(:purpose) }
  it { is_expected.to validate_presence_of(:model) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to define_enum_for(:purpose).with_values(summary: 0, tagging: 1, embedding: 2, answer: 3) }
  it { is_expected.to define_enum_for(:status).with_values(success: 0, error: 1) }
end
