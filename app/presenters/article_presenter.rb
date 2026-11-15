class ArticlePresenter < SimpleDelegator
  def display_title
    title.presence || url
  end
end
