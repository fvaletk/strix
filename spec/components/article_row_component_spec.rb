require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe ArticleRowComponent, type: :component do
  def render_row(article) = render_inline(described_class.new(article:))

  it "renders a ready Article with title, meta, TL;DR, Tags and badge", :aggregate_failures do
    article = create(:article, :ready, url: "https://www.bees.org/a", title: "Bees", summary_tldr: "Bees make honey.", word_count: 900)
    article.tags << create(:tag, name: "insects")

    html = render_row(article)

    expect(html.at_css("a[href='/articles/#{article.id}']").text).to eq("Bees")
    expect(html.text).to include("bees.org", "Bees make honey.", "insects", "ready")
    expect(html.at_css("a").parent["class"]).to include("font-serif")
  end

  it "falls back to the URL as a sans title when there is no title yet", :aggregate_failures do
    article = create(:article, url: "https://example.com/x")

    html = render_row(article)

    expect(html.at_css("a").text).to eq("https://example.com/x")
    expect(html.at_css("a").parent["class"]).to include("font-sans", "text-ink-2")
    expect(html.text).to include("processing")
  end

  it "shows the failure reason for a failed Article" do
    article = create(:article, :failed, failure_reason: "needs JavaScript")
    expect(render_row(article).text).to include("failed", "needs JavaScript")
  end

  it "notes when tagging failed" do
    article = create(:article, :ready, tagging_failed: true)
    expect(render_row(article).text).to include("Tagging failed")
  end

  it "has no failure note otherwise" do
    expect(render_row(create(:article, :ready)).text).not_to include("Tagging failed")
  end
end
