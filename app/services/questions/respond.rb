module Questions
  # Answers a Question from the most similar Chunks across all Articles (retrieve, then generate).
  # Returns Result.success(answer), or Result.failure(message, code: :llm_error) with no Answer saved
  # when Llm::Client raises.
  class Respond
    NOTHING_FOUND = "Nothing in your Articles covers this.".freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You answer questions for a personal reading assistant using only the numbered Chunks provided.
      Answer only from these Chunks. Do not use outside knowledge.
      Cite the Chunks you rely on as [n], where n is the Chunk's number.
      If the Chunks do not contain the answer, reply exactly: #{NOTHING_FOUND}
    PROMPT

    CITATION = /\[(\d+)\]/

    def self.call(...) = new(...).call

    def initialize(question, client: Llm::Client.new)
      @question = question
      @client = client
      @config = Rails.application.config_for(:strix).fetch(:retrieval)
    end

    def call
      vector = @client.embed(texts: [ @question.text ], task: :query, subject: @question).first
      retrieved = retrieve(vector)
      return save_answer(NOTHING_FOUND, retrieved) if retrieved.empty?

      response = @client.generate(system: SYSTEM_PROMPT, prompt: prompt(retrieved), purpose: "answer", subject: @question)
      save_answer(response.content, retrieved)
    rescue Llm::Error => e
      Result.failure(e.message, code: :llm_error)
    end

    private

    # [[chunk, similarity], ...] ordered best first, at or above min_similarity.
    def retrieve(vector)
      Chunk.includes(:article)
           .nearest_neighbors(:embedding, vector, distance: "cosine")
           .first(@config.fetch(:k))
           .map { |chunk| [ chunk, 1.0 - chunk.neighbor_distance ] }
           .select { |_, similarity| similarity >= @config.fetch(:min_similarity) }
    end

    def prompt(retrieved)
      chunks = retrieved.each_with_index.map do |(chunk, _), index|
        "[#{index + 1}] (#{chunk.article.title.presence || chunk.article.url})\n#{chunk.content}"
      end
      "Question: #{@question.text}\n\nChunks:\n\n#{chunks.join("\n\n")}"
    end

    def save_answer(text, retrieved)
      cited = text.scan(CITATION).flatten.map(&:to_i).to_set
      answer = ActiveRecord::Base.transaction do
        Answer.create!(question: @question, text:).tap do |record|
          retrieved.each_with_index do |(chunk, similarity), index|
            record.answer_chunks.create!(chunk:, similarity:, rank: index + 1, cited: cited.include?(index + 1))
          end
        end
      end
      Result.success(answer)
    end
  end
end
