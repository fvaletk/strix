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

  describe "#domain" do
    it "returns the host without www" do
      expect(described_class.new(build(:article, url: "https://www.example.com/a/b")).domain).to eq("example.com")
    end
  end

  describe "#saved_on" do
    it "formats the creation date" do
      article = build(:article, created_at: Time.zone.local(2026, 3, 5, 10))
      expect(described_class.new(article).saved_on).to eq("Mar 5, 2026")
    end
  end

  describe "#word_count_label" do
    it "pluralises the word count" do
      expect(described_class.new(build(:article, word_count: 1200)).word_count_label).to eq("1,200 words")
    end

    it "is nil when the word count is unknown" do
      expect(described_class.new(build(:article, word_count: nil)).word_count_label).to be_nil
    end
  end

  describe "#sorted_tags" do
    it "lists Tags alphabetically" do
      article = create(:article)
      article.tags << create(:tag, name: "zebra")
      article.tags << create(:tag, name: "ant")
      expect(described_class.new(article).sorted_tags.map(&:name)).to eq(%w[ant zebra])
    end
  end
end
