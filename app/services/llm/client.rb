module Llm
  # The only place Strix talks to an LLM. Provider-specific code stays in this namespace.
  #
  # Deliberate deviation from the #call + Result service convention: this is an adapter at the
  # provider boundary, not a business-rule service. Failures raise Llm::Error so jobs can retry
  # on #retryable?.
  class Client
    BASE_URL = "https://generativelanguage.googleapis.com".freeze
    TIMEOUT = 60

    def initialize
      @config = Rails.application.config_for(:strix).fetch(:llm)
    end

    def generate(system:, prompt:, purpose:, subject: nil, schema: nil, thinking: @config.fetch(:thinking_level))
      model = @config.fetch(:text_model)
      started = monotonic_ms
      usage = {}

      begin
        data = post(model, ENV.fetch("GEMINI_API_KEY"), request_body(system:, prompt:, schema:, thinking:))
        usage = usage_from(data)
        response = Response.new(content: extract(data, parse: schema.present?), **usage)
        log(purpose:, model:, subject:, started:, status: :success, **usage)
        response
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        fail_with(Error.new("Gemini request failed: #{e.message}", retryable: true), purpose:, model:, subject:, started:)
      rescue KeyError => e
        fail_with(Error.new("Missing configuration: #{e.message}"), purpose:, model:, subject:, started:)
      rescue Faraday::ParsingError => e
        fail_with(Error.new("Malformed Gemini response: #{e.message}"), purpose:, model:, subject:, started:)
      rescue Faraday::Error => e
        fail_with(Error.new("Gemini request failed: #{e.message}"), purpose:, model:, subject:, started:)
      rescue Error => e
        fail_with(e, purpose:, model:, subject:, started:, **usage)
      end
    end

    private

    def request_body(system:, prompt:, schema:, thinking:)
      config = { thinkingConfig: { thinkingLevel: thinking.to_s } }
      config.merge!(responseMimeType: "application/json", responseJsonSchema: schema) if schema
      {
        systemInstruction: { parts: [ { text: system } ] },
        contents: [ { role: "user", parts: [ { text: prompt } ] } ],
        generationConfig: config
      }
    end

    def post(model, api_key, body)
      response = connection(api_key).post("/v1beta/models/#{model}:generateContent", body)
      unless response.success?
        raise Error.new("Gemini HTTP #{response.status}: #{error_text(response.body)}",
                        retryable: response.status == 429 || response.status >= 500)
      end
      response.body
    end

    def connection(api_key)
      Faraday.new(url: BASE_URL, headers: { "x-goog-api-key" => api_key }) do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
      end
    end

    def error_text(body)
      body.is_a?(Hash) ? body.dig("error", "message").to_s : body.to_s.truncate(200)
    end

    def extract(data, parse:)
      raise Error, "Malformed Gemini response" unless data.is_a?(Hash)

      parts = data.dig("candidates", 0, "content", "parts")
      text = Array(parts).filter_map { |part| part["text"] if part.is_a?(Hash) && !part["thought"] }.join
      raise Error, "Gemini response has no text" if text.blank?

      parse ? JSON.parse(text) : text
    rescue JSON::ParserError
      raise Error, "Gemini returned invalid JSON"
    end

    def usage_from(data)
      meta = data.is_a?(Hash) ? data["usageMetadata"] || {} : {}
      {
        input_tokens: meta["promptTokenCount"],
        output_tokens: meta["candidatesTokenCount"],
        thinking_tokens: meta["thoughtsTokenCount"]
      }
    end

    def fail_with(error, started:, **attrs)
      log(started:, status: :error, error_message: error.message, **attrs)
      raise error
    end

    def log(purpose:, model:, subject:, started:, status:, error_message: nil, **tokens)
      LlmCall.create!(purpose:, model:, subject:, status:, error_message:,
                      latency_ms: monotonic_ms - started, **tokens)
    end

    def monotonic_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
  end
end
