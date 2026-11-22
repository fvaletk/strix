require "rails_helper"

RSpec.describe Articles::BuildChunks do
  subject(:call) { described_class.call(article, client:) }

  let(:client) { instance_double(Llm::Client) }
  let(:text) { Array.new(40) { |i| "Sentence #{i} " + ([ "word" ] * 38).join(" ") + "." }.join(" ") }
  let(:article) { create(:article, :ready, text:) }

  def fake_vector(value = 0.1) = Array.new(1536, value)

  before do
    allow(client).to receive(:embed) { |texts:, **| texts.map { fake_vector } }
  end

  it "stores ordered Chunks with content, word count and embedding", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    call
    chunks = article.chunks.reload
    expect(chunks.size).to be > 1
    expect(chunks.map(&:position)).to eq((0...chunks.size).to_a)
    expect(chunks.map(&:word_count)).to eq(chunks.map { |chunk| chunk.content.split.size })
    expect(chunks.first.embedding.size).to eq(1536)
  end

  it "uses the configured chunk size and overlap", :aggregate_failures do
    call
    words = Rails.application.config_for(:strix).fetch(:chunking)
    chunks = article.chunks.reload
    expect(chunks.map(&:word_count)).to all(be <= words.fetch(:words))
    expect(chunks.first.content.split.last(words.fetch(:overlap_words))).to eq(chunks.second.content.split.first(words.fetch(:overlap_words)))
  end

  it "yields one Chunk for a text shorter than a Chunk" do
    article.update!(text: "A short article.")
    call
    expect(article.chunks.reload.map(&:content)).to eq([ "A short article." ])
  end

  it "embeds all Chunks as documents in one batched call for the Article" do
    call
    expect(client).to have_received(:embed).once.with(
      texts: article.chunks.reload.map(&:content), task: :document, subject: article
    )
  end

  it "replaces the Article's existing Chunks" do
    create(:chunk, article:, position: 0, content: "old")
    call
    expect(article.chunks.reload.map(&:content)).not_to include("old")
  end

  it "is idempotent" do
    call
    expect { described_class.call(article, client:) }.not_to change { article.chunks.reload.map(&:content) }
  end

  it "keeps the old Chunks when embedding fails", :aggregate_failures do
    old = create(:chunk, article:, position: 0, content: "old")
    allow(client).to receive(:embed).and_raise(Llm::Error.new("boom", retryable: true))
    expect { call }.to raise_error(Llm::Error)
    expect(article.chunks.reload).to eq([ old ])
  end

  it "keeps the old Chunks when saving fails", :aggregate_failures do
    old = create(:chunk, article:, position: 0, content: "old")
    allow(client).to receive(:embed).and_return([ fake_vector ])
    expect { call }.to raise_error(StandardError)
    expect(article.chunks.reload).to eq([ old ])
  end

  [ nil, "", "  \n " ].each do |blank|
    it "raises for an Article whose text is #{blank.inspect} and creates no Chunks", :aggregate_failures do
      article.update!(text: blank)
      expect { call }.to raise_error(described_class::EmptyTextError)
      expect(article.chunks.reload).to be_empty
    end
  end
end
