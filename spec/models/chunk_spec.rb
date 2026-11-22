require "rails_helper"

RSpec.describe Chunk, type: :model do
  subject(:chunk) { build(:chunk) }

  it { is_expected.to belong_to(:article) }
  it { is_expected.to validate_presence_of(:content) }
  it { is_expected.to validate_presence_of(:word_count) }
  it { is_expected.to validate_presence_of(:embedding) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:word_count).only_integer.is_greater_than(0) }

  it "requires a unique position within an Article" do
    existing = create(:chunk, position: 0)
    expect(build(:chunk, article: existing.article, position: 0)).not_to be_valid
  end

  it "is destroyed with its Article" do
    chunk = create(:chunk)
    expect { chunk.article.destroy }.to change(described_class, :count).by(-1)
  end

  it "stores a 1536-float embedding" do
    expect(create(:chunk).reload.embedding.size).to eq(1536)
  end
end
