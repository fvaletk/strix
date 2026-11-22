require "rails_helper"

RSpec.describe "Articles", type: :request do
  let!(:user) { create(:user) }

  describe "GET /" do
    it "is the Articles list" do
      get "/"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /articles" do
    before do
      create(:article, user:, url: "https://example.com/old", title: "Old title", created_at: 2.days.ago)
      create(:article, user:, url: "https://example.com/fresh", created_at: 1.day.ago)
      create(:article, url: "https://example.com/other-user")
      get "/articles"
    end

    it "shows title (or URL when untitled) and status, only for the User", :aggregate_failures do
      expect(response.body).to include("Old title", "https://example.com/fresh", "processing")
      expect(response.body).not_to include("other-user")
    end

    it "orders newest first" do
      expect(response.body.index("https://example.com/fresh")).to be < response.body.index("Old title")
    end

    it "includes the save form" do
      get "/articles"
      expect(response.body).to include('action="/articles"')
    end
  end

  describe "GET /articles/:id" do
    it "shows URL, title and status" do
      article = create(:article, :ready, user:, url: "https://example.com/a", title: "Hello")
      get "/articles/#{article.id}"
      expect(response.body).to include("https://example.com/a", "Hello", "ready")
    end

    it "shows the Summary TL;DR and key points when present", :aggregate_failures do
      article = create(:article, :ready, user:, summary_tldr: "Short take. Second sentence.",
                                         summary_key_points: [ "Point one", "Point two", "Point three" ])
      get "/articles/#{article.id}"
      expect(response.body).to include("Short take. Second sentence.", "Point one", "Point two", "Point three")
    end

    it "omits the Summary section when absent" do
      article = create(:article, :ready, user:)
      get "/articles/#{article.id}"
      expect(response.body).not_to include("TL;DR")
    end

    it "shows the Article's Tags and no failure notice", :aggregate_failures do
      article = create(:article, :ready, user:)
      article.tags << create(:tag, user:, name: "bees", description: "About bees")
      get "/articles/#{article.id}"
      expect(response.body).to include("bees", "About bees")
      expect(response.body).not_to include("Tagging failed")
    end

    it "shows a tagging failed notice when the flag is set" do
      article = create(:article, :ready, user:, tagging_failed: true)
      get "/articles/#{article.id}"
      expect(response.body).to include("Tagging failed")
    end

    it "returns 404 for another User's Article" do
      other = create(:article)
      get "/articles/#{other.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /articles" do
    it "creates a processing Article with the normalized URL and redirects to it", :aggregate_failures do
      post "/articles", params: { article: { url: "https://Example.com/post/?utm_source=x#top" } }

      article = user.articles.last
      expect([ article.url, article.status ]).to eq([ "https://example.com/post", "processing" ])
      expect(response).to redirect_to(article_path(article))
    end

    it "redirects to the existing Article and creates nothing when the URL is already saved", :aggregate_failures do
      existing = create(:article, user:, url: "https://example.com/post")

      expect {
        post "/articles", params: { article: { url: "https://EXAMPLE.com/post/?fbclid=1" } }
      }.not_to change(Article, :count)

      expect(response).to redirect_to(article_path(existing))
    end

    it "re-renders the form with an error for an invalid URL", :aggregate_failures do
      expect {
        post "/articles", params: { article: { url: "ftp://example.com/a" } }
      }.not_to change(Article, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("must be a valid http or https URL")
    end

    it "re-renders with an error for a blank URL" do
      post "/articles", params: { article: { url: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
