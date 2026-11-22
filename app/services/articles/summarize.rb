module Articles
  # Writes an Article's Summary with one structured-output call and returns the Article.
  # Deliberately raises (not Result.failure): the processing job retries transient Llm::Errors
  # and fails the Article on non-retryable ones, so invalid model output raises a non-retryable Llm::Error.
  class Summarize
    KEY_POINTS_RANGE = (3..5)

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You summarize articles for a personal reading assistant.
      Write a two-sentence TL;DR and #{KEY_POINTS_RANGE.min}-#{KEY_POINTS_RANGE.max} key points. Keep the whole summary under 150 words.
      Always write in English, regardless of the article's language.
      Include only claims found in the text. Do not add outside knowledge or opinions.
    PROMPT

    SCHEMA = {
      type: "object",
      properties: {
        tldr: { type: "string" },
        key_points: { type: "array", items: { type: "string" }, minItems: KEY_POINTS_RANGE.min, maxItems: KEY_POINTS_RANGE.max }
      },
      required: %w[tldr key_points]
    }.freeze

    def self.call(...) = new(...).call

    def initialize(article, client: Llm::Client.new)
      @article = article
      @client = client
    end

    def call
      response = @client.generate(
        system: SYSTEM_PROMPT,
        prompt: "Title: #{@article.title}\n\n#{@article.text}",
        purpose: "summary",
        subject: @article,
        schema: SCHEMA
      )
      tldr, key_points = parse_summary(response.content)
      @article.update!(summary_tldr: tldr, summary_key_points: key_points)
      @article
    end

    private

    def parse_summary(content)
      tldr = content.is_a?(Hash) ? content["tldr"].to_s.strip : ""
      key_points = content.is_a?(Hash) ? Array(content["key_points"]) : []
      raise Llm::Error.new("Summary TL;DR is empty", retryable: false) if tldr.empty?
      unless KEY_POINTS_RANGE.cover?(key_points.size)
        raise Llm::Error.new("Summary has #{key_points.size} key points, expected #{KEY_POINTS_RANGE.min}-#{KEY_POINTS_RANGE.max}", retryable: false)
      end

      [ tldr, key_points ]
    end
  end
end
