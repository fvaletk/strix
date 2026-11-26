require "rails_helper"

RSpec.describe Articles::AssignTags do
  subject(:result) { described_class.call(article, client:) }

  let(:client) { instance_double(Llm::Client) }
  let(:user) { create(:user) }
  let(:article) do
    create(:article, :ready, user:, title: "Bees", summary_tldr: "Bees make honey.", summary_key_points: %w[a b c])
  end
  let(:list_turn) { turn(calls: [ call_for("list_tags") ]) }

  def call_for(name, arguments = {}, id: "c-#{name}")
    Llm::ToolCall.new(id:, name:, arguments:)
  end

  def turn(text: nil, calls: [])
    Llm::Turn.new(text:, tool_calls: calls, provider_content: { raw: calls.map(&:id) },
                  input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
  end

  def script(*turns)
    allow(client).to receive(:chat).and_return(*turns)
  end


  context "when the model lists Tags then assigns them" do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:ruby) { create(:tag, user:, name: "ruby", description: "Ruby language") }
    let(:assign_turn) do
      turn(calls: [ call_for("assign_tags", { "existing" => [ "ruby" ], "new" => [ { "name" => "bees", "description" => "About bees" } ] }) ])
    end

    before do
      create(:article_tag, tag: ruby, article: create(:article, user:))
      script(list_turn, assign_turn)
    end

    it "replaces the Article's Tags, creating new ones", :aggregate_failures do
      article.tags << create(:tag, user:, name: "old")
      expect(result).to be_success
      expect(article.reload.tags.map(&:name)).to contain_exactly("ruby", "bees")
      expect(user.tags.find_by(name: "bees").description).to eq("About bees")
    end

    it "calls chat exactly twice, with no call after the terminal assign_tags" do
      result
      expect(client).to have_received(:chat).twice
    end

    it "sets tagging_failed to false" do
      article.update!(tagging_failed: true)
      result
      expect(article.reload.tagging_failed).to be(false)
    end

    it "sends every turn with purpose tagging, the Article as subject, and the system prompt", :aggregate_failures do
      result
      expect(client).to have_received(:chat).with(
        a_hash_including(purpose: "tagging", subject: article, system: Articles::AssignTags::SYSTEM_PROMPT)
      ).twice
      expect(Articles::AssignTags::SYSTEM_PROMPT).to include("list_tags", "5")
    end

    it "returns Tag names, descriptions and Article counts from list_tags, echoing the turn unedited", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      captured = []
      allow(client).to receive(:chat) do |messages:, **|
        captured << messages.dup
        captured.size == 1 ? list_turn : assign_turn
      end
      result
      second = captured.last
      expect(second.first).to include(role: :user, content: a_string_including("Bees", "Bees make honey."))
      expect(second).to include(list_turn.to_message)
      tool_result = second.last
      expect(tool_result).to include(role: :tool_result, tool_call_id: "c-list_tags", name: "list_tags")
      expect(tool_result[:content]).to eq(
        "tags" => [ { "name" => "ruby", "description" => "Ruby language", "article_count" => 1 } ]
      )
    end
  end

  context "when assign_tags is invalid" do
    def assign(existing: [], new: [])
      turn(calls: [ call_for("assign_tags", { "existing" => existing, "new" => new }, id: "a#{rand(1000)}") ])
    end

    let(:good) { assign(new: [ { "name" => "bees", "description" => "d" } ]) }

    before { create(:tag, user:, name: "ruby") }

    def error_for(bad)
      captured = nil
      allow(client).to receive(:chat) do |messages:, **|
        captured = messages.dup
        [ list_turn, bad, good ][captured.count { |m| m[:role] == :assistant }]
      end
      result
      captured
    end

    {
      "more than 5 Tags in total" => -> { { new: %w[a b c d e f].map { |n| { "name" => n, "description" => "d" } } } },
      "a name that is not kebab-case" => -> { { new: [ { "name" => "Not Kebab", "description" => "d" } ] } },
      "an existing name that does not exist" => -> { { existing: [ "nope" ] } },
      "a new name that already exists" => -> { { new: [ { "name" => "ruby", "description" => "d" } ] } }
    }.each do |label, args|
      it "returns an error to the model for #{label} and accepts a corrected retry", :aggregate_failures do
        messages = error_for(assign(**instance_exec(&args)))
        error_message = messages.reverse.find { |m| m[:role] == :tool_result && m[:name] == "assign_tags" }
        expect(error_message[:content]).to include("error" => a_kind_of(String))
        expect(result).to be_success
        expect(article.reload.tags.map(&:name)).to eq([ "bees" ])
      end
    end

    def malformed(arguments)
      turn(calls: [ call_for("assign_tags", arguments, id: "a#{rand(1000)}") ])
    end

    {
      "new as an array of strings" => { "existing" => [], "new" => [ "foo" ] },
      "new as a bare hash" => { "existing" => [], "new" => { "name" => "bees", "description" => "d" } },
      "existing as an array of non-strings" => { "existing" => [ { "a" => 1 } ], "new" => [] },
      "existing as a string" => { "existing" => "ruby", "new" => [] }
    }.each do |label, arguments|
      it "returns an error to the model for malformed arguments (#{label}) and accepts a corrected retry", :aggregate_failures do
        messages = error_for(malformed(arguments))
        error_message = messages.reverse.find { |m| m[:role] == :tool_result && m[:name] == "assign_tags" }
        expect(error_message[:content]).to include("error" => a_kind_of(String))
        expect(result).to be_success
        expect(article.reload.tags.map(&:name)).to eq([ "bees" ])
      end
    end

    it "leaves the Article's Tags unchanged after a rejected assign" do
      article.tags << Tag.find_by!(name: "ruby")
      script(list_turn, assign(existing: [ "nope" ]), turn(text: "give up"))
      result
      expect(article.reload.tags.map(&:name)).to eq([ "ruby" ])
    end
  end

  context "when turns carry text alongside tool calls or several calls" do
    let(:assign_call) { call_for("assign_tags", { "existing" => [], "new" => [ { "name" => "bees", "description" => "d" } ] }) }

    it "follows the tool calls, not the text, when a turn has both and several calls", :aggregate_failures do
      mixed = turn(text: "I will not use tools", calls: [ call_for("list_tags"), assign_call ])
      script(mixed)
      expect(result).to be_success
      expect(client).to have_received(:chat).once
      expect(article.reload.tags.map(&:name)).to eq([ "bees" ])
    end

    it "lists only the User's own Tags" do # rubocop:disable RSpec/ExampleLength
      create(:tag, name: "foreign")
      create(:tag, user:, name: "mine")
      captured = []
      allow(client).to receive(:chat) do |messages:, **|
        captured << messages.dup
        captured.size == 1 ? list_turn : turn(text: "done")
      end
      result
      expect(captured.last.last[:content]["tags"].map { |t| t["name"] }).to eq([ "mine" ])
    end
  end

  context "when the Article has no Summary" do
    before do
      article.update!(summary_tldr: " ")
      article.tags << create(:tag, user:, name: "old")
      allow(client).to receive(:chat)
    end

    it "makes no chat call" do
      result
      expect(client).not_to have_received(:chat)
    end

    it "fails with :missing_summary, flags tagging_failed and leaves Tags unchanged", :aggregate_failures do
      expect(result).to be_failure
      expect(result.code).to eq(:missing_summary)
      expect(article.reload.tagging_failed).to be(true)
      expect(article.tags.map(&:name)).to eq([ "old" ])
    end
  end

  context "when the loop does not succeed" do
    let(:bad_assign) { turn(calls: [ call_for("assign_tags", { "existing" => [ "nope" ], "new" => [] }) ]) }

    it "stops after 5 turns, marks tagging_failed and leaves Tags unchanged", :aggregate_failures do
      script(list_turn, bad_assign, bad_assign, bad_assign, bad_assign, bad_assign)
      expect(result).to be_failure
      expect(client).to have_received(:chat).exactly(5).times
      expect(article.reload.tagging_failed).to be(true)
      expect(article.tags).to be_empty
    end

    it "marks tagging_failed when the model replies with text only", :aggregate_failures do
      script(turn(text: "I think it's about bees"))
      expect(result).to be_failure
      expect(client).to have_received(:chat).once
      expect(article.reload.tagging_failed).to be(true)
    end

    it "marks tagging_failed on a non-retryable Llm::Error", :aggregate_failures do
      allow(client).to receive(:chat).and_raise(Llm::Error.new("bad", retryable: false))
      expect(result).to be_failure
      expect(article.reload.tagging_failed).to be(true)
    end

    it "propagates a retryable Llm::Error without marking the Article", :aggregate_failures do
      allow(client).to receive(:chat).and_raise(Llm::Error.new("busy", retryable: true))
      expect { result }.to raise_error(Llm::Error)
      expect(article.reload.tagging_failed).to be(false)
    end

    it "answers an unknown tool with an error and keeps going", :aggregate_failures do
      script(turn(calls: [ call_for("bogus") ]), turn(text: "done"))
      expect(result).to be_failure
      expect(client).to have_received(:chat).twice
    end
  end
end
