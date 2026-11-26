require "rails_helper"

RSpec.describe Question, type: :model do
  subject { build(:question) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_one(:answer).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:text) }
end
