require "rails_helper"

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleMemoizedHelpers, RSpec/LetSetup

RSpec.describe Questions::Respond do
  subject(:result) { described_class.call(question, client:) }

  let(:client) { instance_double(Llm::Client) }
  let(:question) { create(:question, text: "What do bees make?") }
  let(:generated) { "Bees make honey [1]. Also [3] and [9]." }

  # Unit vectors in the plane of the first two axes: cosine similarity to the query [1, 0, ...] is cos(angle).
  def vector_with_similarity(sim)
    Array.new(1536) { 0.0 }.tap do |v|
      v[0] = sim
      v[1] = Math.sqrt(1 - (sim * sim))
    end
  end

  def query_vector = Array.new(1536) { 0.0 }.tap { |v| v[0] = 1.0 }

  def seed_chunk(sim, title:, content: "Content #{title}")
    article = create(:article, :ready, title:)
    create(:chunk, article:, content:, embedding: vector_with_similarity(sim))
  end

  def response_with(content)
    Llm::Response.new(content:, input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
  end

  before do
    allow(client).to receive_messages(embed: [ query_vector ], generate: response_with(generated))
  end

  it "embeds the Question as a query with the Question as subject" do
    seed_chunk(0.9, title: "Bees")
    result
    expect(client).to have_received(:embed).with(texts: [ "What do bees make?" ], task: :query, subject: question)
  end

  context "when Chunks are above the cutoff" do
    let!(:best) { seed_chunk(0.95, title: "Bees") }
    let!(:second) { seed_chunk(0.8, title: "Honey") }
    let!(:third) { seed_chunk(0.7, title: "Wax") }
    let!(:low) { seed_chunk(0.3, title: "Cars") }

    it "is a success with the generated Answer saved", :aggregate_failures do
      expect(result).to be_success
      expect(result.data).to be_persisted
      expect(result.data.question).to eq(question)
      expect(result.data.text).to eq(generated)
    end

    it "stores retrieved Chunks by rank with similarity, dropping those below min_similarity", :aggregate_failures do
      records = result.data.answer_chunks
      expect(records.map(&:chunk)).to eq([ best, second, third ])
      expect(records.map(&:rank)).to eq([ 1, 2, 3 ])
      expect(records.map(&:similarity)).to all(be_a(Float))
      expect(records.first.similarity).to be_within(0.001).of(0.95)
    end

    it "marks cited Chunks and ignores markers outside the retrieved set" do
      expect(result.data.answer_chunks.map(&:cited)).to eq([ true, false, true ])
    end

    it "asks the model with the system prompt, numbered Chunks with Article titles, and the Question", :aggregate_failures do
      result
      expect(client).to have_received(:generate).with(
        system: a_string_including("only from", "[n]", "Nothing in your Articles covers this."),
        prompt: a_string_including("What do bees make?", "[1]", "Bees", "Content Bees", "[3]", "Wax"),
        purpose: "answer",
        subject: question
      )
    end

    it "does not send Chunks below the cutoff" do
      result
      expect(client).to have_received(:generate).with(hash_including(prompt: satisfy { |p| p.exclude?("Cars") }))
    end
  end

  context "when only k Chunks are retrieved" do
    it "limits to retrieval.k" do
      10.times { |i| seed_chunk(0.9 - (i * 0.01), title: "T#{i}") }
      expect(result.data.answer_chunks.count).to eq(8)
    end
  end

  context "when no Chunk reaches min_similarity" do
    before { seed_chunk(0.3, title: "Cars") }

    it "answers exactly that nothing covers it and makes no generation call", :aggregate_failures do
      expect(result).to be_success
      expect(result.data.text).to eq("Nothing in your Articles covers this.")
      expect(result.data.answer_chunks).to be_empty
      expect(client).not_to have_received(:generate)
    end
  end

  context "when Llm::Client raises Llm::Error" do
    before do
      seed_chunk(0.9, title: "Bees")
      allow(client).to receive(:generate).and_raise(Llm::Error.new("boom"))
    end

    it "returns a failure, saves no Answer and keeps the Question", :aggregate_failures do
      expect(result).to be_failure
      expect(Answer.count).to eq(0)
      expect(question).to be_persisted
    end
  end

  context "when embedding raises Llm::Error" do
    before { allow(client).to receive(:embed).and_raise(Llm::Error.new("boom")) }

    it "returns a failure" do
      expect(result).to be_failure
    end
  end
end
