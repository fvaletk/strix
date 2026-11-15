require "rails_helper"

RSpec.describe ArticlePresenter do
  describe "#display_title" do
    it "returns the title when present" do
      article = build(:article, title: "A Post", url: "https://example.com/post")
      expect(described_class.new(article).display_title).to eq("A Post")
    end

    it "falls back to the URL when the title is blank" do
      article = build(:article, title: "", url: "https://example.com/post")
      expect(described_class.new(article).display_title).to eq("https://example.com/post")
    end
  end
end
