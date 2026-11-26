class NoticeComponent < ApplicationComponent
  VARIANTS = {
    info: "bg-mint text-accent-hover",
    failure: "bg-warn-soft text-warn-ink",
    partial: "bg-partial-bg text-partial-ink border border-dashed border-latte-deep"
  }.freeze

  def initialize(variant:, role: "status")
    @variant = variant
    @role = role
  end

  erb_template <<~ERB
    <div role="<%= @role %>" class="rounded-[14px] px-4 py-3 text-[15px] <%= VARIANTS.fetch(@variant) %>"><%= content %></div>
  ERB
end
