require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe "Designed pages", type: :request do
  let!(:user) { create(:user) }

  def doc = Nokogiri::HTML(response.body)

  it "renders [n] markers as citation links to the matching source card", :aggregate_failures do
    question = create(:question, user:)
    answer = create(:answer, question:, text: "Honey [1].")
    create(:answer_chunk, :cited, answer:, chunk: create(:chunk, article: create(:article, :ready, title: "Bees")), rank: 1)

    get "/questions/#{question.id}"

    expect(doc.at_css("a[href='#source-1']").text).to eq("1")
    expect(doc.at_css("#source-1").text).to include("Bees")
  end

  it "renders the empty state with both actions when nothing was found", :aggregate_failures do
    question = create(:question, user:)
    create(:answer, question:, text: Questions::Respond::NOTHING_FOUND)

    get "/questions/#{question.id}"

    expect(response.body).to include("Nothing in your Articles covers this.")
    expect(doc.css("a").map { |a| a.text.strip }).to include("Save an Article", "Ask something else")
  end

  it "shows the failure notice and no retry for a Question without an Answer", :aggregate_failures do
    question = create(:question, user:)
    get "/questions/#{question.id}"

    expect(response.body).to include("No answer yet.")
    expect(response.body).not_to include("Couldn&#39;t answer")
    expect(doc.css("a").map { |a| a.text.strip }).to include("Ask another Question")
  end

  it "lists a No answer pill on the Questions list" do
    create(:question, user:)
    get "/questions"
    expect(response.body).to include("No answer")
  end

  it "shows the Article count and only the latest 3 Questions on the Ask page", :aggregate_failures do
    create_list(:article, 2, user:)
    4.times { |i| create(:question, user:, text: "Question number #{i}", created_at: i.days.ago) }

    get "/questions/new"

    expect(response.body).to include("Searches all 2 Articles", "Question number 0", "Question number 2")
    expect(response.body).not_to include("Question number 3")
  end

  it "shows the failure reason and skeleton states on the Article page", :aggregate_failures do
    failed = create(:article, :failed, user:, failure_reason: "needs JavaScript")
    get "/articles/#{failed.id}"
    expect(response.body).to include("Couldn't extract this page", "Reason: needs JavaScript")

    processing = create(:article, user:)
    get "/articles/#{processing.id}"
    expect(response.body).to include("Strix is reading this page")
  end
end
