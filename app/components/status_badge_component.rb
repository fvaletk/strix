class StatusBadgeComponent < ApplicationComponent
  STYLES = {
    "processing" => "bg-mint text-accent",
    "ready" => "bg-neutral-chip text-ink-2",
    "failed" => "bg-warn-soft text-warn"
  }.freeze

  def initialize(status:)
    @status = status.to_s
  end

  erb_template <<~ERB
    <span class="inline-flex items-center gap-2 rounded-full px-3 py-1 text-[13px] font-semibold capitalize <%= STYLES.fetch(@status) %>">
      <span aria-hidden="true" class="size-[7px] rounded-full bg-current"></span><%= @status %>
    </span>
  ERB
end
