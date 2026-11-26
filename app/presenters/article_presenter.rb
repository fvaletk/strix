class ArticlePresenter < SimpleDelegator
  def display_title
    title.presence || url
  end

  def domain
    URI.parse(url).host.to_s.delete_prefix("www.")
  rescue URI::InvalidURIError
    url
  end

  def saved_on
    created_at.strftime("%b %-d, %Y")
  end

  def word_count_label
    return if word_count.blank?

    "#{ActiveSupport::NumberHelper.number_to_delimited(word_count)} #{"word".pluralize(word_count)}"
  end

  # Sorted in Ruby so preloaded Tags are used.
  def sorted_tags
    tags.sort_by(&:name)
  end
end
