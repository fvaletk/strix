# Turns an Article's URL into readable text by trying an ordered list of
# strategies. Each strategy responds to #call(url) and returns a Result whose
# data is { title:, text:, word_count: }. Adding a strategy = adding a class
# to STRATEGIES.
class Extraction
  STRATEGIES = [ Extraction::StaticFetch ].freeze

  def self.call(...) = new(...).call

  def initialize(article, strategies: STRATEGIES, resolver: Extraction::Resolver)
    @article = article
    @strategies = strategies
    @resolver = resolver
  end

  def call
    result = nil
    @strategies.each do |strategy|
      result = strategy.new(resolver: @resolver, config:).call(@article.url)
      return save(result.data) if result.success?
    end
    result || Result.failure("no extraction strategy", code: :no_strategy)
  end

  private

  def save(data)
    @article.update!(title: data[:title], text: data[:text], word_count: data[:word_count])
    Result.success(@article)
  end

  def config
    Rails.application.config_for(:strix).fetch(:extraction)
  end
end
