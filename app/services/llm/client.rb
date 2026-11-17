module Llm
  # The only place Strix talks to an LLM. Provider-specific code stays in this namespace.
  #
  # Deliberate deviation from the #call + Result service convention: this is an adapter at the
  # provider boundary, not a business-rule service. Failures raise Llm::Error so jobs can retry
  # on #retryable?.
  class Client
    BASE_URL = "https://generativelanguage.googleapis.com".freeze
    TIMEOUT = 60
    # batchEmbedContents accepts at most 100 texts per request.
    EMBED_BATCH_SIZE = 100
    # gemini-embedding-2 has no task_type field; the task is expressed as a prefix on the text.
    EMBEDDING_PREFIXES = {
      document: "title: none | text: %<text>s",
      query: "task: question answering | query: %<text>s"
    }.freeze

    def initialize
      @config = Rails.application.config_for(:strix).fetch(:llm)
    end

    def generate(system:, prompt:, purpose:, subject: nil, schema: nil, thinking: @config.fetch(:thinking_level))
      model = @config.fetch(:text_model)
      tracking(purpose:, model:, subject:) do |usage|
        data = post("/v1beta/models/#{model}:generateContent", request_body(system:, prompt:, schema:, thinking:))
        usage.merge!(usage_from(data))
        Response.new(content: extract(data, parse: schema.present?), **usage)
      end
    end

    # One conversation turn with tools; returns an Llm::Turn. The caller owns the loop.
    #
    # tools:    [{ name:, description:, parameters: <JSON schema> }]
    # messages: [{ role: :user, content: "text" },
    #             turn.to_message,  # role: :assistant (+ text, tool_calls, opaque provider_content)
    #             { role: :tool_result, tool_call_id:, name:, content: <Hash> }]
    # Consecutive :tool_result messages are sent as a single user turn.
    def chat(system:, messages:, tools:, purpose:, subject: nil, thinking: @config.fetch(:thinking_level))
      model = @config.fetch(:text_model)
      contents = chat_contents(messages)
      tracking(purpose:, model:, subject:) do |usage|
        body = {
          systemInstruction: { parts: [ { text: system } ] },
          contents:,
          generationConfig: { thinkingConfig: { thinkingLevel: thinking.to_s } }
        }
        body[:tools] = [ { functionDeclarations: tools.map { |tool| function_declaration(tool) } } ] if tools.any?
        data = post("/v1beta/models/#{model}:generateContent", body)
        usage.merge!(usage_from(data))
        extract_turn(data, **usage)
      end
    end

    # Returns one unit-length vector per text, in input order. task: is :document or :query.
    def embed(texts:, task:, purpose: "embedding", subject: nil)
      template = EMBEDDING_PREFIXES.fetch(task) { raise ArgumentError, "Unknown embedding task: #{task.inspect}" }
      return [] if texts.empty?

      model = @config.fetch(:embedding_model)
      dimensions = @config.fetch(:embedding_dimensions)
      texts.each_slice(EMBED_BATCH_SIZE).flat_map do |group|
        embed_batch(group, template:, model:, dimensions:, purpose:, subject:)
      end
    end

    private

    # One batchEmbedContents request, logged as one LlmCall.
    def embed_batch(texts, template:, model:, dimensions:, purpose:, subject:)
      tracking(purpose:, model:, subject:) do |usage|
        requests = texts.map do |text|
          { model: "models/#{model}", content: { parts: [ { text: format(template, text:) } ] }, outputDimensionality: dimensions }
        end
        data = post("/v1beta/models/#{model}:batchEmbedContents", { requests: })
        usage.merge!(input_tokens: usage_from(data)[:input_tokens])
        extract_vectors(data, count: texts.size, dimensions:)
      end
    end

    def function_declaration(tool)
      tool = tool.to_h.symbolize_keys
      { name: tool.fetch(:name), description: tool.fetch(:description), parameters: tool.fetch(:parameters) }
    end

    def chat_contents(messages)
      messages.map { |message| message.to_h.symbolize_keys }.chunk_while do |a, b|
        a[:role].to_s == "tool_result" && b[:role].to_s == "tool_result"
      end.map { |group| chat_content(group) }
    end

    def chat_content(group)
      first = group.first
      case first[:role].to_s
      when "user" then { role: "user", parts: [ { text: required(first, :content) } ] }
      when "assistant" then first[:provider_content] || { role: "model", parts: assistant_parts(first) }
      when "tool_result" then { role: "user", parts: group.map { |message| function_response(message) } }
      else raise ArgumentError, "Unknown message role: #{first[:role].inspect}"
      end
    end

    def function_response(message)
      content = required(message, :content)
      response = content.is_a?(Hash) ? content : { result: content }
      { functionResponse: { id: required(message, :tool_call_id), name: required(message, :name), response: } }
    end

    def required(message, key)
      message.fetch(key) { raise ArgumentError, "Message #{message[:role].inspect} is missing #{key}" }
    end

    def assistant_parts(message)
      parts = message[:text].present? ? [ { text: message[:text] } ] : []
      parts + Array(message[:tool_calls]).map do |call|
        { functionCall: { name: call.name, args: call.arguments, id: call.id } }
      end
    end

    def extract_turn(data, **usage)
      raise Error, "Malformed Gemini response" unless data.is_a?(Hash)

      content = data.dig("candidates", 0, "content")
      parts = Array(content.is_a?(Hash) ? content["parts"] : nil).select { |part| part.is_a?(Hash) }
      text = parts.filter_map { |part| part["text"] if !part["thought"] }.join.presence
      calls = parts.filter_map { |part| part["functionCall"] }.map do |call|
        ToolCall.new(id: call["id"], name: call["name"], arguments: call["args"] || {})
      end
      raise Error, "Gemini response has no text or tool calls" if text.nil? && calls.empty?

      Turn.new(text:, tool_calls: calls, provider_content: content, **usage)
    end

    def request_body(system:, prompt:, schema:, thinking:)
      config = { thinkingConfig: { thinkingLevel: thinking.to_s } }
      config.merge!(responseMimeType: "application/json", responseJsonSchema: schema) if schema
      {
        systemInstruction: { parts: [ { text: system } ] },
        contents: [ { role: "user", parts: [ { text: prompt } ] } ],
        generationConfig: config
      }
    end

    # Runs the block (which fills the usage hash), logging one LlmCall and mapping failures to Llm::Error.
    def tracking(purpose:, model:, subject:)
      started = monotonic_ms
      usage = {}
      begin
        result = yield usage
        log(purpose:, model:, subject:, started:, status: :success, **usage)
        result
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

    def extract_vectors(data, count:, dimensions:)
      raise Error, "Malformed Gemini response" unless data.is_a?(Hash)

      vectors = Array(data["embeddings"]).map { |embedding| embedding.is_a?(Hash) ? embedding["values"] : nil }
      raise Error, "Expected #{count} embeddings, got #{vectors.size}" unless vectors.size == count
      unless vectors.all? { |v| v.is_a?(Array) && v.size == dimensions && v.all?(Numeric) }
        raise Error, "Embedding does not have #{dimensions} dimensions"
      end

      vectors.map { |v| normalize(v) }
    end

    # Truncated (Matryoshka) vectors are not guaranteed unit length; normalizing is idempotent.
    def normalize(vector)
      norm = Math.sqrt(vector.sum { |x| x * x })
      norm.zero? ? vector : vector.map { |x| x / norm }
    end

    def post(path, body)
      response = connection(ENV.fetch("GEMINI_API_KEY")).post(path, body)
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
