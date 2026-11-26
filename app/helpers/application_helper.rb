module ApplicationHelper
  NAV_ITEMS = [
    [ :articles, "Articles" ],
    [ :ask, "Ask" ],
    [ :questions, "Questions" ]
  ].freeze

  def current_section
    if controller_name == "articles"
      :articles
    elsif controller_name == "questions" && %w[new create].include?(action_name)
      :ask
    elsif controller_name == "questions"
      :questions
    end
  end

  def nav_link(section, label)
    path = { articles: articles_path, ask: new_question_path, questions: questions_path }.fetch(section)
    current = section == current_section
    classes = "inline-flex min-h-11 items-center rounded-[10px] px-3.5 text-[15px] text-ink-2 hover:bg-neutral-chip"
    classes = "#{classes} bg-neutral-chip font-bold text-ink" if current
    link_to label, path, class: classes, aria: { current: ("page" if current) }
  end

  BUTTONS = {
    primary: "bg-accent text-white hover:bg-accent-hover border border-accent",
    secondary: "bg-surface text-ink border border-control hover:bg-neutral-chip",
    quiet: "text-accent hover:underline"
  }.freeze

  def button_classes(kind)
    "inline-flex h-12 items-center justify-center rounded-[10px] px-6 font-semibold #{BUTTONS.fetch(kind)}"
  end
end
