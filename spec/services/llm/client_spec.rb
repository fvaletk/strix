require "rails_helper"

RSpec.describe Llm::Client do
  subject(:client) { described_class.new }

  let(:endpoint) { "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent" }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:body) do
    {
      candidates: [ { content: { parts: [ { text: "Hello there" } ] } } ],
      usageMetadata: { promptTokenCount: 12, candidatesTokenCount: 5, thoughtsTokenCount: 30 }
    }
  end

  before { stub_const("ENV", ENV.to_h.merge("GEMINI_API_KEY" => "test-key")) }

  def generate(**opts)
    client.generate(system: "Be brief", prompt: "Say hi", purpose: :summary, **opts)
  end

  def raised_error
    generate
  rescue Llm::Error => e
    e
  end

  def raised_error_with(**opts)
    generate(**opts)
  rescue Llm::Error => e
    e
  end

  def sent_body
    JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
  end

  describe "#generate" do
    context "when Gemini answers with text" do
      before { stub_request(:post, endpoint).to_return(status: 200, body: body.to_json, headers: json_headers) }

      it "returns the text and token usage" do
        result = generate
        expect(result).to have_attributes(content: "Hello there", input_tokens: 12, output_tokens: 5, thinking_tokens: 30)
      end

      it "sends the system instruction, prompt and API key", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        generate
        expect(WebMock).to have_requested(:post, endpoint).with(headers: { "x-goog-api-key" => "test-key" })
        expect(sent_body).to include(
          "systemInstruction" => { "parts" => [ { "text" => "Be brief" } ] },
          "contents" => [ { "role" => "user", "parts" => [ { "text" => "Say hi" } ] } ]
        )
      end

      it "sends the configured thinking level by default" do
        generate
        expect(sent_body.dig("generationConfig", "thinkingConfig", "thinkingLevel")).to eq("medium")
      end

      it "lets the caller override the thinking level" do
        generate(thinking: "high")
        expect(sent_body.dig("generationConfig", "thinkingConfig", "thinkingLevel")).to eq("high")
      end

      it "does not request structured output without a schema" do
        generate
        expect(sent_body["generationConfig"]).not_to include("responseMimeType")
      end

      it "logs a successful LlmCall", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        article = create(:article)
        expect { generate(subject: article) }.to change(LlmCall, :count).by(1)
        expect(LlmCall.last).to have_attributes(
          purpose: "summary", model: "gemini-3.5-flash-lite", status: "success",
          input_tokens: 12, output_tokens: 5, thinking_tokens: 30, subject: article, error_message: nil
        )
        expect(LlmCall.last.latency_ms).to be >= 0
      end

      it "logs without a subject when none is given" do
        generate
        expect(LlmCall.last.subject).to be_nil
      end
    end

    context "when reading the API key" do
      it "does not need the key to build the client" do
        stub_const("ENV", ENV.to_h.except("GEMINI_API_KEY"))
        expect { described_class.new }.not_to raise_error
      end

      it "raises a non-retryable Llm::Error at call time when the key is missing" do
        stub_const("ENV", ENV.to_h.except("GEMINI_API_KEY"))
        expect(raised_error).to be_an(Llm::Error).and have_attributes(retryable?: false, message: /GEMINI_API_KEY/)
      end

      it "logs the missing-key failure" do
        stub_const("ENV", ENV.to_h.except("GEMINI_API_KEY"))
        raised_error
        expect(LlmCall.last).to have_attributes(status: "error", error_message: /GEMINI_API_KEY/)
      end
    end

    context "when a failed call has a subject" do
      it "logs the error against the subject", :aggregate_failures do
        article = create(:article)
        stub_request(:post, endpoint).to_return(status: 500, body: "{}", headers: json_headers)
        raised_error_with(subject: article)
        expect(LlmCall.last).to have_attributes(status: "error", subject: article, purpose: "summary")
        expect(LlmCall.last.latency_ms).to be >= 0
      end
    end

    context "when a schema is given" do
      let(:schema) { { type: "object", properties: { tags: { type: "array", items: { type: "string" } } } } }
      let(:json_body) { body.deep_merge(candidates: [ { content: { parts: [ { text: '{"tags":["a","b"]}' } ] } } ]) }

      it "uses structured output and returns parsed JSON", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        stub_request(:post, endpoint).to_return(status: 200, body: json_body.to_json, headers: json_headers)
        result = generate(schema:)
        expect(result.content).to eq("tags" => %w[a b])
        expect(sent_body["generationConfig"]).to include(
          "responseMimeType" => "application/json", "responseJsonSchema" => schema.deep_stringify_keys
        )
      end

      it "raises a non-retryable Llm::Error when the text is not JSON" do
        stub_request(:post, endpoint).to_return(status: 200, body: body.to_json, headers: json_headers)
        expect(raised_error_with(schema:)).to be_an(Llm::Error).and have_attributes(retryable?: false)
      end
    end

    context "when a validate: callable is given" do
      before { stub_request(:post, endpoint).to_return(status: 200, body: body.to_json, headers: json_headers) }

      it "runs it on the parsed content and returns the response" do
        seen = nil
        result = generate(validate: ->(content) { seen = content })
        expect([ seen, result.content ]).to eq([ "Hello there", "Hello there" ])
      end

      it "logs an Llm::Error it raises as a failed call with token usage, and re-raises it unchanged", :aggregate_failures do
        validate = ->(_content) { raise Llm::Error.new("too short", retryable: false) }
        expect(raised_error_with(validate:)).to be_an(Llm::Error).and have_attributes(message: "too short", retryable?: false)
        expect(LlmCall.last).to have_attributes(status: "error", error_message: "too short",
                                                input_tokens: 12, output_tokens: 5, thinking_tokens: 30)
      end

      it "logs only the failed call", :aggregate_failures do
        validate = ->(_content) { raise Llm::Error.new("nope") }
        raised_error_with(validate:)
        expect(LlmCall.pluck(:status)).to eq([ "error" ])
      end
    end

    context "when the call fails" do
      let(:error_body) { { error: { message: "nope" } }.to_json }

      [ 429, 500, 503 ].each do |code|
        it "raises a retryable Llm::Error on HTTP #{code}" do
          stub_request(:post, endpoint).to_return(status: code, body: error_body, headers: json_headers)
          expect(raised_error).to have_attributes(retryable?: true)
        end

        it "logs the HTTP #{code} failure", :aggregate_failures do
          stub_request(:post, endpoint).to_return(status: code, body: error_body, headers: json_headers)
          raised_error
          expect(LlmCall.last).to have_attributes(status: "error", model: "gemini-3.5-flash-lite")
          expect(LlmCall.last.error_message).to include("nope")
        end
      end

      it "raises a non-retryable Llm::Error on HTTP 400" do
        stub_request(:post, endpoint).to_return(status: 400, body: "{}", headers: json_headers)
        expect(raised_error).to have_attributes(retryable?: false)
      end

      it "raises a retryable Llm::Error on timeout and logs it" do
        stub_request(:post, endpoint).to_timeout
        expect(raised_error).to have_attributes(retryable?: true)
      end

      it "logs the timeout" do
        stub_request(:post, endpoint).to_timeout
        raised_error
        expect(LlmCall.last).to have_attributes(status: "error")
      end

      it "raises a non-retryable Llm::Error on a malformed response" do
        stub_request(:post, endpoint).to_return(status: 200, body: "<html>")
        expect(raised_error).to have_attributes(retryable?: false)
      end

      it "raises and logs a non-retryable Llm::Error on invalid JSON with a JSON content type", :aggregate_failures do
        stub_request(:post, endpoint).to_return(status: 200, body: "<html>", headers: json_headers)
        expect(raised_error).to be_an(Llm::Error).and have_attributes(retryable?: false)
        expect(LlmCall.last).to have_attributes(status: "error")
      end

      it "wraps other Faraday errors as a non-retryable Llm::Error and logs them", :aggregate_failures do
        stub_request(:post, endpoint).to_raise(Faraday::SSLError.new("bad cert"))
        expect(raised_error).to be_an(Llm::Error).and have_attributes(retryable?: false)
        expect(LlmCall.last).to have_attributes(status: "error", error_message: /bad cert/)
      end

      it "joins text from all non-thought parts" do
        parts = [ { text: "thinking...", thought: true }, { text: "Hello " }, { text: "there" } ]
        multi = body.merge(candidates: [ { content: { parts: } } ])
        stub_request(:post, endpoint).to_return(status: 200, headers: json_headers, body: multi.to_json)
        expect(generate.content).to eq("Hello there")
      end

      it "raises a non-retryable Llm::Error when there is no candidate text" do
        stub_request(:post, endpoint).to_return(status: 200, body: { candidates: [] }.to_json, headers: json_headers)
        expect(raised_error).to have_attributes(retryable?: false)
      end
    end
  end

  describe "#chat" do
    let(:tools) do
      [ { name: "add_tag", description: "Attach a tag",
          parameters: { type: "object", properties: { tag: { type: "string", enum: %w[ruby rails] } }, required: [ "tag" ] } } ]
    end
    let(:messages) { [ { role: :user, content: "Tag this" } ] }

    def chat(**opts)
      client.chat(system: "Be brief", messages: opts.delete(:messages) || messages, tools:, purpose: :tagging, **opts)
    end

    def chat_error(**opts)
      chat(**opts)
    rescue Llm::Error => e
      e
    end

    def reply(parts, usage: { promptTokenCount: 20, candidatesTokenCount: 4, thoughtsTokenCount: 9 })
      stub_request(:post, endpoint).to_return(
        status: 200, headers: json_headers,
        body: { candidates: [ { content: { role: "model", parts: } } ], usageMetadata: usage }.to_json
      )
    end

    context "when Gemini answers with text" do
      before { reply([ { text: "All done", thoughtSignature: "sig-text" } ]) }

      it "returns the text, no tool calls and token usage" do
        expect(chat).to have_attributes(text: "All done", tool_calls: [], input_tokens: 20, output_tokens: 4, thinking_tokens: 9)
      end

      it "does not surface thought parts as text" do
        reply([ { text: "hmm", thought: true }, { text: "Answer" } ])
        expect(chat.text).to eq("Answer")
      end
    end

    context "when sending the request" do
      before { reply([ { text: "ok" } ]) }

      it "translates neutral tools into function declarations without a toolConfig", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        chat
        expect(sent_body["tools"]).to eq([ { "functionDeclarations" => [ {
          "name" => "add_tag", "description" => "Attach a tag",
          "parameters" => { "type" => "object", "properties" => { "tag" => { "type" => "string", "enum" => %w[ruby rails] } },
                            "required" => [ "tag" ] }
        } ] } ])
        expect(sent_body).not_to include("toolConfig")
      end

      it "sends the system instruction, user message and thinking level", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        chat(thinking: "high")
        expect(sent_body).to include(
          "systemInstruction" => { "parts" => [ { "text" => "Be brief" } ] },
          "contents" => [ { "role" => "user", "parts" => [ { "text" => "Tag this" } ] } ]
        )
        expect(sent_body.dig("generationConfig", "thinkingConfig", "thinkingLevel")).to eq("high")
      end

      it "defaults to the configured thinking level" do
        chat
        expect(sent_body.dig("generationConfig", "thinkingConfig", "thinkingLevel")).to eq("medium")
      end
    end

    context "when Gemini answers with one tool call" do
      before { reply([ { functionCall: { name: "add_tag", args: { tag: "ruby" }, id: "c1" }, thoughtSignature: "sig-1" } ]) }

      it "returns the call with id, name and parsed arguments", :aggregate_failures do
        result = chat
        expect(result.text).to be_nil
        expect(result.tool_calls).to eq([ Llm::ToolCall.new(id: "c1", name: "add_tag", arguments: { "tag" => "ruby" }) ])
      end
    end

    context "when Gemini answers with several tool calls" do
      before do
        reply([ { functionCall: { name: "add_tag", args: { tag: "ruby" }, id: "c1" }, thoughtSignature: "sig-1" },
                { functionCall: { name: "add_tag", args: { tag: "rails" }, id: "c2" } } ])
      end

      it "returns every call in order" do
        expect(chat.tool_calls.map(&:id)).to eq(%w[c1 c2])
      end
    end

    context "when continuing with tool results" do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:first_parts) do
        [ { "functionCall" => { "name" => "add_tag", "args" => { "tag" => "ruby" }, "id" => "c1" }, "thoughtSignature" => "sig-1" },
          { "functionCall" => { "name" => "add_tag", "args" => { "tag" => "rails" }, "id" => "c2" } } ]
      end
      let(:first_turn) do
        stub_request(:post, endpoint).to_return(status: 200, headers: json_headers,
                                                body: { candidates: [ { content: { role: "model", parts: first_parts } } ] }.to_json)
        chat
      end
      let(:followup) do
        messages + [ first_turn.to_message,
                     { role: :tool_result, tool_call_id: "c2", name: "add_tag", content: { ok: false } },
                     { role: :tool_result, tool_call_id: "c1", name: "add_tag", content: { ok: true } } ]
      end

      before do
        first_turn
        WebMock.reset!
        reply([ { text: "Finished" } ])
      end

      it "returns the final text" do
        expect(chat(messages: followup).text).to eq("Finished")
      end

      it "echoes the model parts, signature included, exactly as received" do
        chat(messages: followup)
        expect(sent_body["contents"][1]).to eq("role" => "model", "parts" => first_parts)
      end

      it "sends one user turn with a functionResponse per call, matched by id" do # rubocop:disable RSpec/ExampleLength
        chat(messages: followup)
        expect(sent_body["contents"][2]).to eq(
          "role" => "user",
          "parts" => [ { "functionResponse" => { "id" => "c2", "name" => "add_tag", "response" => { "ok" => false } } },
                       { "functionResponse" => { "id" => "c1", "name" => "add_tag", "response" => { "ok" => true } } } ]
        )
      end

      it "rebuilds a model turn from tool calls when no provider data is present" do # rubocop:disable RSpec/ExampleLength
        message = { role: :assistant, tool_calls: [ Llm::ToolCall.new(id: "c1", name: "add_tag", arguments: { "tag" => "ruby" }) ] }
        chat(messages: messages + [ message ])
        expect(sent_body["contents"][1]).to eq(
          "role" => "model",
          "parts" => [ { "functionCall" => { "name" => "add_tag", "args" => { "tag" => "ruby" }, "id" => "c1" } } ]
        )
      end
    end

    context "when the messages are malformed" do
      before { reply([ { text: "ok" } ]) }

      it "raises ArgumentError for an unknown role without a request or LlmCall", :aggregate_failures do
        expect { chat(messages: [ { role: :robot, content: "hi" } ]) }.to raise_error(ArgumentError, /Unknown message role/)
        expect(a_request(:post, endpoint)).not_to have_been_made
        expect(LlmCall.count).to eq(0)
      end

      it "raises ArgumentError for a tool result missing tool_call_id without a request or LlmCall", :aggregate_failures do
        bad = [ { role: :tool_result, name: "add_tag", content: {} } ]
        expect { chat(messages: bad) }.to raise_error(ArgumentError, /tool_call_id/)
        expect(a_request(:post, endpoint)).not_to have_been_made
        expect(LlmCall.count).to eq(0)
      end

      it "raises ArgumentError for a user message missing content" do
        expect { chat(messages: [ { role: :user } ]) }.to raise_error(ArgumentError, /content/)
      end
    end

    context "when a tool result content is not a Hash" do
      before { reply([ { text: "ok" } ]) }

      it "wraps it as { result: content }" do
        chat(messages: messages + [ { role: :tool_result, tool_call_id: "c1", name: "add_tag", content: "done" } ])
        expect(sent_body.dig("contents", 1, "parts", 0, "functionResponse", "response")).to eq("result" => "done")
      end
    end

    context "when there are no tools" do
      before { reply([ { text: "ok" } ]) }

      it "omits the tools key" do
        client.chat(system: "Be brief", messages:, tools: [], purpose: :tagging)
        expect(sent_body).not_to include("tools")
      end
    end

    context "when logging" do
      before { reply([ { text: "ok" } ]) }

      it "logs a successful LlmCall with thinking tokens", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        article = create(:article)
        expect { chat(subject: article) }.to change(LlmCall, :count).by(1)
        expect(LlmCall.last).to have_attributes(
          purpose: "tagging", model: "gemini-3.5-flash-lite", status: "success",
          input_tokens: 20, output_tokens: 4, thinking_tokens: 9, subject: article
        )
      end
    end

    context "when the call fails" do
      [ 429, 503 ].each do |code|
        it "raises a retryable Llm::Error on HTTP #{code} and logs it", :aggregate_failures do
          stub_request(:post, endpoint).to_return(status: code, body: { error: { message: "nope" } }.to_json, headers: json_headers)
          expect(chat_error).to have_attributes(retryable?: true)
          expect(LlmCall.last).to have_attributes(status: "error", purpose: "tagging")
        end
      end

      it "raises a non-retryable Llm::Error on HTTP 400" do
        stub_request(:post, endpoint).to_return(status: 400, body: "{}", headers: json_headers)
        expect(chat_error).to have_attributes(retryable?: false)
      end

      it "raises a retryable Llm::Error on timeout" do
        stub_request(:post, endpoint).to_timeout
        expect(chat_error).to have_attributes(retryable?: true)
      end

      it "raises a non-retryable Llm::Error when there is neither text nor a tool call and logs it", :aggregate_failures do
        stub_request(:post, endpoint).to_return(status: 200, body: { candidates: [] }.to_json, headers: json_headers)
        expect(chat_error).to have_attributes(retryable?: false)
        expect(LlmCall.last).to have_attributes(status: "error")
      end
    end
  end

  describe "#embed" do
    def embed_endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:batchEmbedContents"
    def unit = Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 }
    def other = Array.new(1536) { |i| i == 1 ? 1.0 : 0.0 }
    def embed_body = { embeddings: [ { values: unit }, { values: other } ] }

    def embed(texts: %w[first second], task: :document, **opts)
      client.embed(texts:, task:, **opts)
    end

    def embed_error(**opts)
      embed(**opts)
    rescue Llm::Error => e
      e
    end

    context "when Gemini answers with vectors" do
      before { stub_request(:post, embed_endpoint).to_return(status: 200, body: embed_body.to_json, headers: json_headers) }

      it "returns one vector per text in input order" do
        expect(embed).to eq([ unit, other ])
      end

      it "sends all texts in one batch request with the dimension and API key", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        embed
        expect(WebMock).to have_requested(:post, embed_endpoint).once.with(headers: { "x-goog-api-key" => "test-key" })
        expect(sent_body["requests"]).to eq(
          %w[first second].map do |text|
            { "model" => "models/gemini-embedding-2",
              "content" => { "parts" => [ { "text" => "title: none | text: #{text}" } ] },
              "outputDimensionality" => 1536 }
          end
        )
      end

      it "prefixes :query texts for question answering and sends no taskType", :aggregate_failures do
        embed(task: :query)
        expect(sent_body["requests"].map { |r| r.dig("content", "parts", 0, "text") })
          .to eq([ "task: question answering | query: first", "task: question answering | query: second" ])
        expect(sent_body["requests"].flat_map(&:keys)).not_to include("taskType")
      end

      it "normalizes vectors that are not unit length" do
        scaled = Array.new(1536) { |i| i.zero? ? 3.0 : 0.0 }
        stub_request(:post, embed_endpoint).to_return(
          status: 200, headers: json_headers, body: { embeddings: [ { values: scaled }, { values: other } ] }.to_json
        )
        expect(embed.first).to eq(unit)
      end

      it "returns [] without a request or LlmCall when there are no texts", :aggregate_failures do
        expect { expect(embed(texts: [])).to eq([]) }.not_to change(LlmCall, :count)
        expect(WebMock).not_to have_requested(:post, embed_endpoint)
      end

      it "rejects an unknown task" do
        expect { embed(task: :other) }.to raise_error(ArgumentError)
      end

      it "logs a successful LlmCall without tokens when none are reported", :aggregate_failures do
        article = create(:article)
        expect { embed(subject: article) }.to change(LlmCall, :count).by(1)
        expect(LlmCall.last).to have_attributes(
          purpose: "embedding", model: "gemini-embedding-2", status: "success", subject: article, input_tokens: nil
        )
      end

      it "logs input tokens when reported" do
        with_usage = embed_body.merge(usageMetadata: { promptTokenCount: 9 })
        stub_request(:post, embed_endpoint).to_return(status: 200, headers: json_headers, body: with_usage.to_json)
        embed
        expect(LlmCall.last.input_tokens).to eq(9)
      end

      it "logs the latency" do
        embed
        expect(LlmCall.last.latency_ms).to be >= 0
      end
    end

    context "when there are more texts than one batch allows" do
      let(:texts) { Array.new(150) { |i| "t#{i}" } }

      # Echoes a one-hot vector per text, so each position is distinguishable.
      def echo_response
        lambda do |request|
          vectors = JSON.parse(request.body)["requests"].map do |r|
            index = r.dig("content", "parts", 0, "text")[/t(\d+)\z/, 1].to_i
            { values: Array.new(1536) { |i| i == index ? 1.0 : 0.0 } }
          end
          { status: 200, headers: json_headers, body: { embeddings: vectors }.to_json }
        end
      end

      def batch_sizes
        WebMock::RequestRegistry.instance.requested_signatures.hash.keys.map { |s| JSON.parse(s.body)["requests"].size }
      end

      it "splits into requests of at most 100 and returns vectors in input order", :aggregate_failures do
        stub = stub_request(:post, embed_endpoint).to_return(echo_response)
        result = embed(texts:)
        expect(stub).to have_been_requested.twice
        expect(batch_sizes).to contain_exactly(100, 50)
        expect(result.map { |v| v.index(1.0) }).to eq((0...150).to_a)
      end

      it "writes one LlmCall per request", :aggregate_failures do
        stub_request(:post, embed_endpoint).to_return(echo_response)
        expect { embed(texts:) }.to change(LlmCall, :count).by(2)
        expect(LlmCall.last(2).map(&:status)).to eq(%w[success success])
      end

      it "raises when a later group fails, keeping earlier calls as successes", :aggregate_failures do
        stub_request(:post, embed_endpoint)
          .to_return(echo_response)
          .then.to_return(status: 503, body: { error: { message: "down" } }.to_json, headers: json_headers)
        expect(embed_error(texts:)).to be_an(Llm::Error).and have_attributes(retryable?: true)
        expect(LlmCall.last(2).map(&:status)).to eq(%w[success error])
      end
    end

    context "when the response is wrong" do
      it "raises and logs when a vector has the wrong length", :aggregate_failures do
        stub_request(:post, embed_endpoint).to_return(
          status: 200, headers: json_headers, body: { embeddings: [ { values: [ 0.1 ] }, { values: other } ] }.to_json
        )
        expect(embed_error).to be_an(Llm::Error).and have_attributes(retryable?: false, message: /1536/)
        expect(LlmCall.last).to have_attributes(status: "error", purpose: "embedding")
      end

      it "raises a logged Llm::Error when a vector has non-numeric elements", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        bad = { values: Array.new(1536) { |i| i.zero? ? "x" : 0.0 } }
        stub_request(:post, embed_endpoint).to_return(
          status: 200, headers: json_headers, body: { embeddings: [ bad, { values: other } ] }.to_json
        )
        expect(embed_error).to be_an(Llm::Error).and have_attributes(retryable?: false)
        expect(LlmCall.last).to have_attributes(status: "error", purpose: "embedding")
      end

      it "raises when the vector count does not match the inputs" do
        stub_request(:post, embed_endpoint).to_return(
          status: 200, headers: json_headers, body: { embeddings: [ { values: unit } ] }.to_json
        )
        expect(embed_error).to be_an(Llm::Error).and have_attributes(retryable?: false)
      end
    end

    context "when the call fails" do
      [ 429, 500, 503 ].each do |code|
        it "raises a retryable Llm::Error on HTTP #{code} and logs it", :aggregate_failures do
          stub_request(:post, embed_endpoint).to_return(status: code, body: { error: { message: "nope" } }.to_json, headers: json_headers)
          expect(embed_error).to have_attributes(retryable?: true)
          expect(LlmCall.last).to have_attributes(status: "error", purpose: "embedding", error_message: /nope/)
        end
      end

      it "raises a non-retryable Llm::Error on HTTP 400" do
        stub_request(:post, embed_endpoint).to_return(status: 400, body: "{}", headers: json_headers)
        expect(embed_error).to have_attributes(retryable?: false)
      end

      it "raises a retryable Llm::Error on timeout" do
        stub_request(:post, embed_endpoint).to_timeout
        expect(embed_error).to have_attributes(retryable?: true)
      end

      it "raises a non-retryable Llm::Error when the API key is missing" do
        stub_const("ENV", ENV.to_h.except("GEMINI_API_KEY"))
        expect(embed_error).to have_attributes(retryable?: false, message: /GEMINI_API_KEY/)
      end

      it "raises a non-retryable Llm::Error on a malformed response" do
        stub_request(:post, embed_endpoint).to_return(status: 200, body: "<html>", headers: json_headers)
        expect(embed_error).to have_attributes(retryable?: false)
      end
    end
  end
end
