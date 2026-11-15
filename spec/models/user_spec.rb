require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:articles).dependent(:destroy) }

  describe ".current" do
    it "is the single seeded User" do
      user = create(:user)
      expect(described_class.current).to eq(user)
    end
  end
end
