require "rails_helper"

RSpec.describe Articles::Chunker do
  subject(:chunks) { described_class.call(text, words: 20, overlap_words: 5) }

  def sentence(label, count) = ([ "#{label}w" ] * (count - 1) + [ "end#{label}." ]).join(" ")

  def word_count(chunk) = chunk.split.size

  context "with text shorter than one chunk" do
    let(:text) { "Just a few words here." }

    it { is_expected.to eq([ "Just a few words here." ]) }
  end

  context "with blank text" do
    let(:text) { " \n\n " }

    it { is_expected.to eq([]) }
  end

  context "with several sentences" do
    let(:text) { [ sentence("a", 8), sentence("b", 8), sentence("c", 8), sentence("d", 8) ].join(" ") }

    it "breaks at sentence boundaries where possible" do
      expect(chunks.map { |chunk| chunk.split.last }).to all(match(/\Aend[a-d]\.\z/))
    end

    it "keeps each chunk to about the target size" do
      expect(chunks.map { |chunk| word_count(chunk) }).to all(be <= 20)
    end

    it "overlaps each chunk with the previous by the overlap words" do
      chunks.each_cons(2) do |previous, following|
        expect(following.split.first(5)).to eq(previous.split.last(5))
      end
    end

    it "covers all the text" do
      expect(chunks.join(" ")).to include("endd.")
    end
  end

  context "with paragraphs" do
    let(:text) { "#{sentence('a', 12)}\n\n#{sentence('b', 12)}" }

    it "breaks between paragraphs" do
      expect(chunks.first.split.last).to eq("enda.")
    end
  end

  context "with a sentence longer than a chunk" do
    let(:text) { ([ "word" ] * 50).join(" ") + "." }

    it "falls back to splitting by words", :aggregate_failures do
      expect(chunks.map { |chunk| word_count(chunk) }).to all(be <= 20)
      expect(chunks.size).to be > 2
    end
  end
end
