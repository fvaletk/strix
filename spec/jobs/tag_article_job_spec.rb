require "rails_helper"

# rubocop:disable RSpec/ExampleLength
RSpec.describe TagArticleJob do
  include ActiveJob::TestHelper

  let(:article) { create(:article, :ready, tagging_failed: true, title: "Bees", summary_tldr: "Bees.", summary_key_points: %w[a b c]) }
  let(:client) { instance_double(Llm::Client) }

  before { allow(Llm::Client).to receive(:new).and_return(client) }

  def run(id = article.id)
    perform_enqueued_jobs { described_class.perform_later(id) }
  end

  it "reruns only tagging and clears tagging_failed on success", :aggregate_failures do
    call = Llm::ToolCall.new(id: "c1", name: "assign_tags", arguments: { "existing" => [], "new" => [ { "name" => "bees", "description" => "Bees" } ] })
    allow(client).to receive(:chat).and_return(
      Llm::Turn.new(text: nil, tool_calls: [ call ], provider_content: {}, input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
    )
    run
    article.reload
    expect(article.tags.map(&:name)).to eq([ "bees" ])
    expect(article).not_to be_tagging_failed
  end

  it "keeps tagging_failed and the status when retries run out", :aggregate_failures do
    allow(client).to receive(:chat).and_raise(Llm::Error.new("boom", retryable: true))
    run
    article.reload
    expect(article).to be_tagging_failed
    expect(article).to be_ready
    expect(client).to have_received(:chat).exactly(3).times
  end

  it "retries a transient error and then succeeds", :aggregate_failures do
    call = Llm::ToolCall.new(id: "c1", name: "assign_tags", arguments: { "existing" => [], "new" => [ { "name" => "bees", "description" => "Bees" } ] })
    turn = Llm::Turn.new(text: nil, tool_calls: [ call ], provider_content: {}, input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
    calls = 0
    allow(client).to receive(:chat) { (calls += 1) == 1 ? raise(Llm::Error.new("boom", retryable: true)) : turn }
    run
    expect(article.reload).not_to be_tagging_failed
    expect(article.tags.map(&:name)).to eq([ "bees" ])
  end

  it "exits quietly when the Article no longer exists" do
    expect { run(0) }.not_to raise_error
  end
end
# rubocop:enable RSpec/ExampleLength
