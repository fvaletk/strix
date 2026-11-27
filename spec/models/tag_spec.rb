require "rails_helper"

RSpec.describe Tag, type: :model do
  subject(:tag) { build(:tag) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:articles).through(:article_tags) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:description) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:user_id) }

  it "accepts lowercase kebab-case names" do
    expect(build(:tag, name: "machine-learning-2")).to be_valid
  end

  it "rejects names that are not lowercase kebab-case", :aggregate_failures do
    [ "Machine Learning", "machine_learning", "-lead", "trail-", "dou--ble", "UPPER" ].each do |name|
      expect(build(:tag, name:)).not_to be_valid
    end
  end

  it "rejects a description with a line break", :aggregate_failures do
    [ "one\ntwo", "one\r\ntwo", "one\rtwo" ].each do |description|
      expect(build(:tag, description:)).not_to be_valid
    end
  end

  it "strips whitespace around a single-line description", :aggregate_failures do
    tag = build(:tag, description: "  A one-liner \n")
    expect(tag).to be_valid
    expect(tag.description).to eq("A one-liner")
  end

  it "allows the same name for different Users" do
    create(:tag, name: "ruby")
    expect(build(:tag, name: "ruby")).to be_valid
  end
end
