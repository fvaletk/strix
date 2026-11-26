require "rails_helper"

RSpec.describe QuestionPresenter do
  describe "#result" do
    it "is :no_answer without an Answer" do
      expect(described_class.new(create(:question)).result).to eq(:no_answer)
    end

    it "is :nothing_found for the nothing-found Answer" do
      answer = create(:answer, text: Questions::Respond::NOTHING_FOUND)
      expect(described_class.new(answer.question).result).to eq(:nothing_found)
    end

    it "is :cited with the cited Article count otherwise", :aggregate_failures do
      answer = create(:answer)
      create(:answer_chunk, :cited, answer:, chunk: create(:chunk), rank: 1)
      presenter = described_class.new(answer.question)

      expect(presenter.result).to eq(:cited)
      expect(presenter.result_label).to eq("1 Article cited")
    end
  end

  describe "#result_label" do
    let(:answer) { create(:answer) }
    let(:article) { create(:article, :ready) }

    before do
      create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article:), rank: 1)
      create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article:), rank: 2)
      create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article: create(:article, :ready)), rank: 3)
      create(:answer_chunk, answer:, chunk: create(:chunk), rank: 4)
    end

    it "counts distinct cited Articles, ignoring uncited chunks" do
      question = Question.includes(answer: { answer_chunks: :chunk }).find(answer.question_id)
      expect(described_class.new(question).result_label).to eq("2 Articles cited")
    end
  end

  describe "#asked_on" do
    it "formats the creation date" do
      question = build(:question, created_at: Time.zone.local(2026, 3, 5))
      expect(described_class.new(question).asked_on).to eq("Mar 5, 2026")
    end
  end
end
