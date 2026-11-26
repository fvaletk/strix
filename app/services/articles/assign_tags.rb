module Articles
  # Tags an Article with a tool-using agent. Strix owns the loop; Llm::Client#chat runs one turn.
  # assign_tags is a terminal tool: once it succeeds, no further chat call is made.
  # Returns Result.success(article) or Result.failure(message, code: :tagging_failed) (sets tagging_failed).
  # Without a Summary it fails with code :missing_summary and makes no chat call.
  # Retryable Llm::Errors propagate so the job can retry.
  class AssignTags
    MAX_TURNS = 5
    MAX_TAGS = 5

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You tag articles for a personal reading assistant.
      Call list_tags first to see the user's existing Tags (name, description, article count).
      Prefer an existing Tag whose description fits the article. Create a new Tag only when no existing Tag fits.
      Tag names are lowercase kebab-case; a new Tag needs a one-line description.
      Use at most #{MAX_TAGS} Tags in total. Finish by calling assign_tags once.
      If assign_tags returns an error, fix the problem and call it again.
    PROMPT

    TOOLS = [
      {
        name: "list_tags",
        description: "List every existing Tag of the user with its name, description and the number of articles using it.",
        parameters: { type: "object", properties: {} }
      },
      {
        name: "assign_tags",
        description: "Attach Tags to the article, creating the new ones. At most #{MAX_TAGS} in total.",
        parameters: {
          type: "object",
          properties: {
            existing: { type: "array", items: { type: "string" }, description: "Names of existing Tags to reuse" },
            new: {
              type: "array",
              items: {
                type: "object",
                properties: { name: { type: "string" }, description: { type: "string" } },
                required: %w[name description]
              }
            }
          },
          required: %w[existing new]
        }
      }
    ].freeze

    def self.call(...) = new(...).call

    def initialize(article, client: Llm::Client.new)
      @article = article
      @client = client
    end

    def call
      return fail_tagging("Article has no Summary", code: :missing_summary) if @article.summary_tldr.blank?

      messages = [ initial_message ]
      MAX_TURNS.times do
        turn = @client.chat(system: SYSTEM_PROMPT, messages:, tools: TOOLS, purpose: "tagging", subject: @article)
        messages << turn.to_message
        return fail_tagging("Model answered without assigning Tags") unless turn.tool_calls?

        return finish if run_tools(turn.tool_calls, messages)
      end
      fail_tagging("Tagging did not finish within #{MAX_TURNS} turns")
    rescue Llm::Error => e
      raise if e.retryable?

      fail_tagging(e.message)
    end

    private

    def initial_message
      points = Array(@article.summary_key_points).map { |p| "- #{p}" }.join("\n")
      { role: :user, content: "Title: #{@article.title}\n\nSummary: #{@article.summary_tldr}\n\nKey points:\n#{points}" }
    end

    # Appends one tool_result per call. Returns true when assign_tags succeeded.
    def run_tools(calls, messages)
      assigned = false
      calls.each do |call|
        content = assigned ? { "error" => "Tags were already assigned" } : execute(call)
        assigned ||= content["assigned"] == true
        messages << { role: :tool_result, tool_call_id: call.id, name: call.name, content: }
      end
      assigned
    end

    def execute(call)
      case call.name
      when "list_tags" then list_tags
      when "assign_tags" then assign_tags(call.arguments)
      else { "error" => "Unknown tool: #{call.name}" }
      end
    end

    def list_tags
      counts = ArticleTag.where(tag_id: tags.select(:id)).group(:tag_id).count
      { "tags" => tags.order(:name).map { |t| { "name" => t.name, "description" => t.description, "article_count" => counts.fetch(t.id, 0) } } }
    end

    def assign_tags(arguments)
      args = (arguments || {}).to_h.with_indifferent_access
      existing = args.fetch(:existing, [])
      new_tags = args.fetch(:new, [])
      error = shape_error(existing, new_tags) || validation_error(existing, new_tags)
      return { "error" => error } if error

      ActiveRecord::Base.transaction do
        created = new_tags.map { |t| tags.create!(name: t[:name], description: t[:description]) }
        @article.tags = tags.where(name: existing).to_a + created
      end
      { "assigned" => true }
    end

    # Model-supplied arguments can have any shape; reject anything but the documented one.
    def shape_error(existing, new_tags)
      return "existing must be a list of Tag names (strings)" unless existing.is_a?(Array) && existing.all?(String)
      return if new_tags.is_a?(Array) && new_tags.all? { |t| t.is_a?(Hash) && t[:name].is_a?(String) }

      "new must be a list of {name, description}"
    end

    def validation_error(existing, new_tags)
      names = existing + new_tags.map { |t| t[:name].to_s }
      return "At most #{MAX_TAGS} Tags in total, got #{names.size}" if names.size > MAX_TAGS
      return "Duplicate names: #{names.tally.select { |_, n| n > 1 }.keys.join(', ')}" if names.uniq.size != names.size

      bad = names.grep_v(Tag::KEBAB_CASE)
      return "Names must be lowercase kebab-case: #{bad.join(', ')}" if bad.any?

      missing = existing - tags.where(name: existing).pluck(:name)
      return "These existing Tags do not exist: #{missing.join(', ')}" if missing.any?

      taken = tags.where(name: new_tags.map { |t| t[:name] }).pluck(:name)
      return "These new Tags already exist (put them under existing): #{taken.join(', ')}" if taken.any?

      "Every new Tag needs a description" if new_tags.any? { |t| t[:description].to_s.strip.empty? }
    end

    def tags = @article.user.tags

    def finish
      @article.update!(tagging_failed: false)
      Result.success(@article)
    end

    def fail_tagging(message, code: :tagging_failed)
      @article.update!(tagging_failed: true)
      Result.failure(message, code:)
    end
  end
end
