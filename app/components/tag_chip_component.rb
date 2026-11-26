class TagChipComponent < ApplicationComponent
  SIZES = {
    list: "text-[13px]",
    article: "text-sm border border-mint-2"
  }.freeze

  def initialize(name:, size: :list, description: nil)
    @name = name
    @size = size
    @description = description
  end

  erb_template <<~ERB
    <span class="inline-block rounded-md bg-mint px-2 py-0.5 font-medium text-mint-ink <%= SIZES.fetch(@size) %>" title="<%= @description %>"><%= @name %></span>
  ERB
end
