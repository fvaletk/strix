# Runs Extraction -> Summary -> Tagging -> Chunks for an Article, then marks it ready or failed.
#
# Transient Llm::Errors retry via Active Job (3 attempts). Finished steps are serialized with the
# job, so a retry reruns only the step that failed. A fresh perform_later starts from scratch.
class ProcessArticleJob < ApplicationJob
  STEPS = %i[extract summarize tag chunk].freeze

  queue_as :default
  sidekiq_options retry: false

  discard_on ActiveRecord::RecordNotFound

  retry_on Llm::Error, attempts: 3, wait: :polynomially_longer do |job, error|
    job.retries_exhausted(error)
  end

  def perform(article_id)
    @article = Article.find(article_id)
    start unless completed.any?

    STEPS.each do |step|
      next if completed.include?(step)

      @current = step
      return unless send(:"run_#{step}")

      completed << step
    end
    @article.update!(status: :ready, failure_reason: nil)
  end

  def serialize = super.merge("completed" => completed.map(&:to_s))

  def deserialize(job_data)
    super
    @completed = Array(job_data["completed"]).map(&:to_sym)
  end

  # Called by retry_on once attempts run out. A Tagging failure never fails the Article.
  def retries_exhausted(error)
    article = Article.find_by(id: arguments.first)
    return unless article

    if @current == :tag
      article.update!(tagging_failed: true)
      completed << :tag
      self.executions = 0
      self.exception_executions = {}
      enqueue
    else
      article.update!(status: :failed, failure_reason: error.message)
    end
  end

  private

  def completed = @completed ||= []

  def start
    @article.update!(status: :processing, failure_reason: nil)
  end

  def run_extract
    result = Extraction.call(@article)
    return true if result.success?

    fail_article(result.error)
  end

  def run_summarize = guarded { Articles::Summarize.call(@article) }

  def run_tag
    Articles::AssignTags.call(@article)
    true
  end

  def run_chunk = guarded { Articles::BuildChunks.call(@article) }

  # Non-retryable errors fail the Article now; retryable ones propagate to retry_on.
  def guarded
    yield
    true
  rescue Llm::Error => e
    raise if e.retryable?

    fail_article(e.message)
  rescue Articles::BuildChunks::EmptyTextError => e
    fail_article(e.message)
  end

  def fail_article(reason)
    @article.update!(status: :failed, failure_reason: reason)
    false
  end
end
