class Articles::TaggingsController < ApplicationController
  def create
    article = current_user.articles.find(params[:article_id])
    TagArticleJob.perform_later(article.id)
    redirect_to article
  end
end
