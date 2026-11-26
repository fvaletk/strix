require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe SourceCardComponent, type: :component do
  it "renders an anchored, numbered card linking to the Article with its domain and Tags", :aggregate_failures do
    article = create(:article, :ready, url: "https://www.bees.org/honey", title: "Bees")
    article.tags << create(:tag, name: "insects")

    html = render_inline(described_class.new(article:, number: 3))

    expect(html.at_css("#source-3")).to be_present
    expect(html.at_css("a[href='/articles/#{article.id}']").text).to include("Bees")
    expect(html.text).to include("3", "bees.org", "insects")
  end

  it "falls back to the URL when the Article has no title" do
    article = create(:article, url: "https://example.com/x")
    expect(render_inline(described_class.new(article:, number: 1)).text).to include("https://example.com/x")
  end
end
