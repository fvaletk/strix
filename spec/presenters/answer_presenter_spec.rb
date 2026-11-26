require "rails_helper"

RSpec.describe AnswerPresenter do
  let(:answer) { create(:answer, text: "Bees make honey [1] and wax [2][3].\n\nWasps sting [9].") }
  let(:bees) { create(:article, :ready, title: "Bees") }
  let(:wax) { create(:article, :ready, title: "Wax") }

  before do
    create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article: bees), rank: 1)
    create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article: wax), rank: 2)
    create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article: bees), rank: 3)
  end

  describe "#sources" do
    it "lists each cited Article once with a 1-based number" do
      expect(described_class.new(answer).sources).to eq([ [ bees, 1 ], [ wax, 2 ] ])
    end
  end

  describe "#paragraphs" do
    it "splits paragraphs and markers, mapping markers to source numbers; unknown markers stay text", :aggregate_failures do
      paragraphs = described_class.new(answer).paragraphs

      expect(paragraphs.first).to eq([ "Bees make honey ", 1, " and wax ", 2, 1, "." ])
      expect(paragraphs.last).to eq([ "Wasps sting ", "[9]", "." ])
    end
  end

  describe "#nothing_found?" do
    it "is true for the nothing-found Answer only", :aggregate_failures do
      expect(described_class.new(build(:answer, text: Questions::Respond::NOTHING_FOUND))).to be_nothing_found
      expect(described_class.new(answer)).not_to be_nothing_found
    end
  end
end
