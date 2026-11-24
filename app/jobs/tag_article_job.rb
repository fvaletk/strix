# Reruns only Articles::AssignTags (the "Retry tagging" button). Never changes the Article's status.
class TagArticleJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  discard_on ActiveRecord::RecordNotFound

  retry_on Llm::Error, attempts: 3, wait: :polynomially_longer do |job, _error|
    Article.where(id: job.arguments.first).update_all(tagging_failed: true)
  end

  def perform(article_id)
    Articles::AssignTags.call(Article.find(article_id))
  end
end
