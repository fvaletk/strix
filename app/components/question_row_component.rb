class QuestionRowComponent < ApplicationComponent
  PILLS = {
    cited: "bg-mint text-mint-ink",
    nothing_found: "bg-neutral-chip text-ink-2",
    no_answer: "bg-warn-soft text-warn"
  }.freeze

  def initialize(question:)
    @question = QuestionPresenter.new(question)
  end

  erb_template <<~ERB
    <div class="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-surface p-5">
      <div class="min-w-0">
        <%= link_to @question.text.truncate(120), question_path(@question), class: "inline-flex min-h-11 items-center font-serif text-xl text-ink hover:underline" %>
        <p class="text-sm text-ink-3"><%= @question.asked_on %></p>
      </div>
      <span data-result class="rounded-full px-3 py-1 text-[13px] font-semibold <%= PILLS.fetch(@question.result) %>"><%= @question.result_label %></span>
    </div>
  ERB
end
