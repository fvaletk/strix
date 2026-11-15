class ArticlesController < ApplicationController
  def index
    @articles = current_user.articles.order(created_at: :desc, id: :desc)
    @article = Article.new
  end

  def show
    @article = current_user.articles.find(params[:id])
  end

  def create
    result = Articles::SaveService.call(user: current_user, url: article_params[:url])

    if result.success?
      redirect_to result.data
    else
      @article = result.data
      @articles = current_user.articles.order(created_at: :desc, id: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def article_params
    params.expect(article: [ :url ])
  end

  def current_user
    @current_user ||= User.current
  end
end
