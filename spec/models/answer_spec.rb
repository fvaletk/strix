require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe Answer, type: :model do
  subject { build(:answer) }

  it { is_expected.to belong_to(:question) }
  it { is_expected.to have_many(:answer_chunks).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:text) }

  describe "#cited_articles" do
    it "returns the Articles of cited Chunks only", :aggregate_failures do
      answer = create(:answer)
      cited = create(:chunk)
      other = create(:chunk)
      create(:answer_chunk, :cited, answer:, chunk: cited, rank: 1)
      create(:answer_chunk, answer:, chunk: other, rank: 2)
      expect(answer.cited_articles).to contain_exactly(cited.article)
    end
  end
end
