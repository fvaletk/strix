require "rails_helper"

RSpec.describe Result do
  describe ".success" do
    subject(:result) { described_class.success("payload", code: :created) }

    it "is a success carrying data and code", :aggregate_failures do
      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result).to have_attributes(data: "payload", code: :created, error: nil)
    end

    it "defaults data and code to nil" do
      expect(described_class.success).to have_attributes(data: nil, code: nil)
    end
  end

  describe ".failure" do
    subject(:result) { described_class.failure("boom", code: :invalid, data: :x) }

    it "is a failure carrying error, code and data", :aggregate_failures do
      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result).to have_attributes(error: "boom", code: :invalid, data: :x)
    end
  end
end
