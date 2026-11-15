require "rails_helper"

RSpec.describe Article, type: :model do
  subject(:article) { build(:article) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:url) }
  it { is_expected.to define_enum_for(:status).with_values(processing: 0, ready: 1, failed: 2) }

  it "defaults to processing with tagging_failed false", :aggregate_failures do
    fresh = described_class.new
    expect(fresh).to be_processing
    expect(fresh.tagging_failed).to be false
  end

  describe "URL normalization" do
    def normalized(url) = build(:article, url:).tap(&:valid?).url

    it "lowercases scheme and host, drops fragment, tracking params and trailing slash" do
      expect(normalized("HTTPS://Example.com/post/?utm_source=x#top")).to eq("https://example.com/post")
    end

    it "drops utm_*, fbclid and gclid but keeps other params" do
      expect(normalized("https://example.com/p?id=1&utm_medium=a&fbclid=b&gclid=c")).to eq("https://example.com/p?id=1")
    end

    it "drops a trailing slash on the bare host" do
      expect(normalized("https://example.com/")).to eq("https://example.com")
    end

    it "strips surrounding whitespace" do
      expect(normalized("  https://example.com/a  ")).to eq("https://example.com/a")
    end
  end

  describe "URL validity" do
    [ "ftp://example.com/a", "not a url", "javascript:alert(1)", "https://", "example.com/a" ].each do |bad|
      it "rejects #{bad.inspect}", :aggregate_failures do
        article = build(:article, url: bad)
        expect(article).not_to be_valid
        expect(article.errors[:url]).to be_present
      end
    end

    it "accepts http" do
      expect(build(:article, url: "http://example.com/a")).to be_valid
    end
  end

  describe "uniqueness" do
    it "rejects the same normalized URL for the same user", :aggregate_failures do
      user = create(:user)
      create(:article, user:, url: "https://example.com/post")
      dup = build(:article, user:, url: "https://Example.com/post/?utm_source=x#top")
      expect(dup).not_to be_valid
      expect(dup.errors[:url]).to be_present
    end

    it "allows the same URL for different users" do
      create(:article, url: "https://example.com/post")
      expect(build(:article, url: "https://example.com/post")).to be_valid
    end
  end
end
