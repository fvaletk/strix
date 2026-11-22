require "rails_helper"

RSpec.describe Articles::Summarize do
  subject(:call) { described_class.call(article, client:) }

  let(:client) { instance_double(Llm::Client) }
  let(:article) { create(:article, :ready, title: "Bees", text: "Bees make honey.") }
  let(:content) { { "tldr" => "Bees make honey. They live in hives.", "key_points" => %w[a b c] } }

  def response_with(content)
    Llm::Response.new(content:, input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
  end

  before { allow(client).to receive(:generate).and_return(response_with(content)) }

  it "stores the TL;DR and key points on the Article", :aggregate_failures do
    call
    article.reload
    expect(article.summary_tldr).to eq("Bees make honey. They live in hives.")
    expect(article.summary_key_points).to eq(%w[a b c])
  end

  it "sends title and text with the system prompt, purpose and subject" do
    call
    expect(client).to have_received(:generate).with(
      a_hash_including(system: a_kind_of(String), prompt: a_string_including("Bees", "Bees make honey."),
                       purpose: "summary", subject: article)
    )
  end

  it "passes a schema requiring a TL;DR string and 3-5 key point strings" do
    call
    key_points = a_hash_including(type: "array", minItems: 3, maxItems: 5)
    properties = a_hash_including(tldr: { type: "string" }, key_points:)
    expect(client).to have_received(:generate).with(a_hash_including(schema: a_hash_including(properties:)))
  end

  it "replaces an existing Summary" do
    article.update!(summary_tldr: "old", summary_key_points: %w[x y z w])
    call
    expect(article.reload.summary_key_points).to eq(%w[a b c])
  end

  [ %w[a b], %w[a b c d e f] ].each do |points|
    it "raises a non-retryable Llm::Error for #{points.size} key points" do
      allow(client).to receive(:generate).and_return(response_with(content.merge("key_points" => points)))
      expect { call }.to raise_error(an_instance_of(Llm::Error).and(having_attributes(retryable?: false)))
    end
  end

  context "with an empty TL;DR" do
    let(:content) { { "tldr" => " ", "key_points" => %w[a b c] } }

    before { article.update!(summary_tldr: "old", summary_key_points: %w[x y z]) }

    it "raises a non-retryable Llm::Error" do
      expect { call }.to raise_error(an_instance_of(Llm::Error).and(having_attributes(retryable?: false)))
    end

    it "keeps the old Summary", :aggregate_failures do
      expect { expect { call }.to raise_error(Llm::Error) }.not_to(change { article.reload.summary_tldr })
    end
  end
end
