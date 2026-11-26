require "rails_helper"

RSpec.describe AnswerChunk, type: :model do
  subject { build(:answer_chunk) }

  it { is_expected.to belong_to(:answer) }
  it { is_expected.to belong_to(:chunk) }
  it { is_expected.to validate_presence_of(:similarity) }
  it { is_expected.to validate_presence_of(:rank) }
  it { is_expected.to validate_numericality_of(:rank).only_integer.is_greater_than(0) }
end
