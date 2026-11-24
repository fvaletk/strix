require "rails_helper"
# Behavior-level job spec: real collaborators, only Llm::Client and HTTP are faked.
# rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/MultipleMemoizedHelpers

RSpec.describe ProcessArticleJob do
  include ActiveJob::TestHelper

  let(:article) { create(:article, url: "https://example.com/post") }
  let(:client) { instance_double(Llm::Client) }
  let(:html) { file_fixture("extraction/article.html").read }
  let(:summary) { Llm::Response.new(content: { "tldr" => "Short.", "key_points" => %w[a b c] }, input_tokens: 1, output_tokens: 1, thinking_tokens: 0) }
  let(:assign_turn) do
    call = Llm::ToolCall.new(id: "c1", name: "assign_tags", arguments: { "existing" => [], "new" => [ { "name" => "bees", "description" => "Bees" } ] })
    Llm::Turn.new(text: nil, tool_calls: [ call ], provider_content: {}, input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
  end
  let!(:page) do
    stub_request(:get, "https://example.com/post")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })
  end

  before do
    allow(Llm::Client).to receive(:new).and_return(client)
    allow(Extraction::Resolver).to receive(:call).and_return([ "93.184.216.34" ])
    allow(client).to receive_messages(generate: summary, chat: assign_turn)
    allow(client).to receive(:embed) { |texts:, **| texts.map { Array.new(1536, 0.1) } }
  end

  def run(id = article.id)
    perform_enqueued_jobs { described_class.perform_later(id) }
  end

  def llm_error(retryable:) = Llm::Error.new("boom", retryable:)

  it "runs every step and marks the Article ready", :aggregate_failures do
    run
    article.reload
    expect(article).to be_ready
    expect(article.title).to be_present
    expect(article.summary_tldr).to eq("Short.")
    expect(article.tags.map(&:name)).to eq([ "bees" ])
    expect(article.chunks).not_to be_empty
  end

  it "exits quietly when the Article no longer exists" do
    expect { run(0) }.not_to raise_error
  end

  it "fails the Article with the Extraction reason and skips later steps", :aggregate_failures do
    stub_request(:get, "https://example.com/post").to_return(status: 404, headers: { "Content-Type" => "text/html" })
    run
    expect(article.reload).to be_failed
    expect(article.failure_reason).to eq("HTTP 404")
    expect(client).not_to have_received(:generate)
  end

  it "fails the Article immediately on a non-retryable Llm::Error in Summary", :aggregate_failures do
    allow(client).to receive(:generate).and_raise(llm_error(retryable: false))
    run
    expect(article.reload).to be_failed
    expect(article.failure_reason).to eq("boom")
    expect(client).to have_received(:generate).once
  end

  it "fails the Article immediately on a non-retryable Llm::Error in Chunks", :aggregate_failures do
    allow(client).to receive(:embed).and_raise(llm_error(retryable: false))
    run
    expect(article.reload).to be_failed
    expect(article.failure_reason).to eq("boom")
  end

  context "with a retryable Llm::Error" do
    it "retries only the failed step and then succeeds", :aggregate_failures do
      calls = 0
      allow(client).to receive(:generate) { (calls += 1) == 1 ? raise(llm_error(retryable: true)) : summary }
      run
      expect(article.reload).to be_ready
      expect(client).to have_received(:generate).twice
      expect(page).to have_been_requested.once
    end

    it "does not repeat Summary or Tagging when Chunks is retried", :aggregate_failures do
      calls = 0
      allow(client).to receive(:embed) do |texts:, **|
        raise llm_error(retryable: true) if (calls += 1) == 1

        texts.map { Array.new(1536, 0.1) }
      end
      run
      expect(article.reload).to be_ready
      expect(client).to have_received(:generate).once
      expect(client).to have_received(:chat).once
      expect(page).to have_been_requested.once
    end

    it "does not repeat Extraction or Summary when Tagging is retried", :aggregate_failures do
      calls = 0
      allow(client).to receive(:chat) { (calls += 1) == 1 ? raise(llm_error(retryable: true)) : assign_turn }
      run
      expect(article.reload).to be_ready
      expect(article).not_to be_tagging_failed
      expect(client).to have_received(:chat).twice
      expect(client).to have_received(:generate).once
      expect(page).to have_been_requested.once
    end

    it "fails the Article with the message when Summary attempts run out", :aggregate_failures do
      allow(client).to receive(:generate).and_raise(llm_error(retryable: true))
      run
      expect(article.reload).to be_failed
      expect(article.failure_reason).to eq("boom")
      expect(client).to have_received(:generate).exactly(3).times
    end

    it "fails the Article with the message when Chunks attempts run out", :aggregate_failures do
      allow(client).to receive(:embed).and_raise(llm_error(retryable: true))
      run
      expect(article.reload).to be_failed
      expect(article.failure_reason).to eq("boom")
      expect(client).to have_received(:embed).exactly(3).times
    end

    it "sets tagging_failed and continues to Chunks when Tagging attempts run out", :aggregate_failures do
      allow(client).to receive(:chat).and_raise(llm_error(retryable: true))
      run
      article.reload
      expect(article).to be_ready
      expect(article).to be_tagging_failed
      expect(article.chunks).not_to be_empty
      expect(client).to have_received(:chat).exactly(3).times
    end

    it "gives Chunks its own 3 attempts after Tagging ran out", :aggregate_failures do
      allow(client).to receive(:chat).and_raise(llm_error(retryable: true))
      allow(client).to receive(:embed).and_raise(llm_error(retryable: true))
      run
      expect(article.reload).to be_failed
      expect(client).to have_received(:embed).exactly(3).times
    end
  end

  it "does not fail the Article when Tagging raises a non-retryable error", :aggregate_failures do
    allow(client).to receive(:chat).and_raise(llm_error(retryable: false))
    run
    article.reload
    expect(article).to be_ready
    expect(article).to be_tagging_failed
    expect(article.chunks).not_to be_empty
  end

  it "is safe to re-run and clears an earlier failure_reason", :aggregate_failures do
    article.update!(status: :failed, failure_reason: "old")
    run
    run
    article.reload
    expect(article).to be_ready
    expect(article.failure_reason).to be_nil
    expect(article.chunks.map(&:position)).to eq((0...article.chunks.size).to_a)
    expect(page).to have_been_requested.twice
  end
end
