class SourceCardComponent < ApplicationComponent
  def initialize(article:, number:)
    @article = ArticlePresenter.new(article)
    @number = number
  end

  erb_template <<~ERB
    <div id="source-<%= @number %>" class="flex items-start gap-4 rounded-2xl border border-border bg-surface p-4">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-mint text-sm font-semibold text-accent"><%= @number %></span>
      <div class="min-w-0">
        <%= link_to @article.display_title, article_path(@article), class: "inline-flex min-h-11 items-center break-words font-serif text-lg font-semibold text-ink hover:underline" %>
        <p class="text-sm text-ink-3"><%= ([ @article.domain ] + @article.sorted_tags.map(&:name)).join(" · ") %></p>
      </div>
    </div>
  ERB
end
