require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders the line, the helper sentence and the actions", :aggregate_failures do
    html = render_inline(described_class.new(title: "Nothing here.", helper: "Try saving one.")) { '<a href="/x">Go</a>'.html_safe }

    expect(html.css("p").map { |p| p.text.strip }).to include("Nothing here.", "Try saving one.")
    expect(html.at_css("a[href='/x']").text).to eq("Go")
    expect(html.at_css("svg")).to be_present
  end
end
