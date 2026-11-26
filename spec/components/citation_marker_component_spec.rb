require "rails_helper"

RSpec.describe CitationMarkerComponent, type: :component do
  it "renders a link to the matching source card", :aggregate_failures do
    link = render_inline(described_class.new(number: 2)).at_css("a")

    expect(link.text.strip).to eq("2")
    expect(link["href"]).to eq("#source-2")
    expect(link["class"].split).to include("bg-mint", "text-accent")
  end
end
