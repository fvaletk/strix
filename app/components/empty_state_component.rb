class EmptyStateComponent < ApplicationComponent
  def initialize(title:, helper:)
    @title = title
    @helper = helper
  end

  erb_template <<~ERB
    <div class="flex flex-col items-center gap-3 px-4 py-8 text-center">
      <svg aria-hidden="true" class="size-10 text-sage" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
      <p class="font-serif text-2xl text-ink"><%= @title %></p>
      <p class="text-ink-2"><%= @helper %></p>
      <div class="mt-2 flex flex-wrap justify-center gap-3"><%= content %></div>
    </div>
  ERB
end
