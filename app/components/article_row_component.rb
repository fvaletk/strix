class ArticleRowComponent < ApplicationComponent
  def initialize(article:)
    @article = ArticlePresenter.new(article)
  end

  def title_classes
    if @article.title.present?
      "font-serif text-[21px] font-semibold text-ink"
    else
      "font-sans text-base text-ink-2 break-all"
    end
  end

  erb_template <<~ERB
    <article class="rounded-2xl border border-border bg-surface p-5">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <h2 class="<%= title_classes %> min-w-0">
          <%= link_to @article.display_title, article_path(@article), class: "inline-flex min-h-11 items-center hover:underline" %>
        </h2>
        <%= render StatusBadgeComponent.new(status: @article.status) %>
      </div>
      <p class="text-sm text-ink-3"><%= @article.domain %> · <%= @article.saved_on %></p>
      <% if @article.failed? && @article.failure_reason.present? %>
        <p class="mt-2 text-sm text-warn"><%= @article.failure_reason %></p>
      <% end %>
      <% if @article.summary_tldr.present? %>
        <p class="mt-3 font-serif text-[17px] text-reading"><%= @article.summary_tldr %></p>
      <% end %>
      <% if @article.sorted_tags.any? %>
        <ul class="mt-3 flex flex-wrap gap-2">
          <% @article.sorted_tags.each do |tag| %>
            <li><%= render TagChipComponent.new(name: tag.name) %></li>
          <% end %>
        </ul>
      <% end %>
      <% if @article.tagging_failed? %>
        <p class="mt-3 text-[13px] text-warn">Tagging failed</p>
      <% end %>
    </article>
  ERB
end
