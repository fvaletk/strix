require "rails_helper"

RSpec.describe "Layout", type: :request do
  before { create(:user) }

  {
    "/articles" => "Articles",
    "/questions/new" => "Ask",
    "/questions" => "Questions"
  }.each do |path, label|
    it "marks #{label} as the current nav item on #{path}", :aggregate_failures do
      get path
      doc = Nokogiri::HTML(response.body)
      current = doc.css("nav a[aria-current='page']")

      expect(current.map { |a| a.text.strip }).to eq([ label ])
      expect(current.first["class"].split).to include("bg-neutral-chip")
    end
  end

  it "shows the wordmark linking to the Articles list and loads the fonts", :aggregate_failures do
    get "/questions"
    doc = Nokogiri::HTML(response.body)

    expect(doc.at_css("header a[href='/articles']").text).to include("Strix")
    expect(doc.css("link[href*='fonts.googleapis.com']")).not_to be_empty
  end
end
