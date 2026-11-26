class CitationMarkerComponent < ApplicationComponent
  def initialize(number:)
    @number = number
  end

  erb_template <<~ERB
    <a href="#source-<%= @number %>" class="relative mx-0.5 inline-block min-w-[22px] rounded-md bg-mint px-1 text-center font-sans text-sm font-semibold leading-[22px] text-accent no-underline after:absolute after:-inset-[11px] after:content-['']"><%= @number %></a>
  ERB
end
