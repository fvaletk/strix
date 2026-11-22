module Articles
  # Splits an Article's text into overlapping Chunks, embeds them as documents and replaces the
  # Article's Chunks. Returns the new Chunks. Raises (the job retries or fails the Article):
  # EmptyTextError when there is nothing to chunk, Llm::Error when embedding fails.
  # Embedding happens before the transaction, so a failure leaves the old Chunks untouched.
  class BuildChunks
    class EmptyTextError < StandardError; end

    def self.call(...) = new(...).call

    def initialize(article, client: Llm::Client.new)
      @article = article
      @client = client
    end

    def call
      contents = Chunker.call(@article.text, words: config.fetch(:words), overlap_words: config.fetch(:overlap_words))
      raise EmptyTextError, "Article #{@article.id} has no text to chunk" if contents.empty?

      embeddings = @client.embed(texts: contents, task: :document, subject: @article)
      replace_chunks(contents, embeddings)
    end

    private

    def config = Rails.application.config_for(:strix).fetch(:chunking)

    def replace_chunks(contents, embeddings)
      ActiveRecord::Base.transaction do
        @article.chunks.destroy_all
        contents.each_with_index.map do |content, position|
          @article.chunks.create!(position:, content:, word_count: content.split.size, embedding: embeddings.fetch(position))
        end
      end
    end
  end
end
