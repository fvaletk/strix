module Articles
  class SaveService
    def self.call(...) = new(...).call

    def initialize(user:, url:)
      @user = user
      @url = Article.normalize_url(url)
    end

    def call
      existing = find_existing
      return Result.success(existing, code: :duplicate) if existing

      article = @user.articles.build(url: @url)
      if article.save
        Result.success(article, code: :created)
      else
        Result.failure("Invalid URL", code: :invalid, data: article)
      end
    rescue ActiveRecord::RecordNotUnique
      Result.success(find_existing, code: :duplicate)
    end

    private

    def find_existing
      return if @url.blank?

      @user.articles.find_by(url: @url)
    end
  end
end
