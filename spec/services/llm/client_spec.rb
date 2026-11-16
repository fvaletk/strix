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
end
