require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe QuestionRowComponent, type: :component do
  def render_row(question) = render_inline(described_class.new(question:))

  it "links the Question with its date and a mint pill for the cited Articles", :aggregate_failures do
    answer = create(:answer, question: create(:question, text: "What do bees make?"))
    create(:answer_chunk, :cited, answer:, chunk: create(:chunk), rank: 1)

    html = render_row(answer.question)

    expect(html.at_css("a[href='/questions/#{answer.question.id}']").text).to include("What do bees make?")
    expect(html.text).to include("1 Article cited")
    expect(html.at_css("[data-result]")["class"].split).to include("bg-mint")
  end

  it "shows a neutral pill when nothing was found", :aggregate_failures do
    question = create(:answer, text: Questions::Respond::NOTHING_FOUND).question
    pill = render_row(question).at_css("[data-result]")

    expect(pill.text.strip).to eq("Nothing found")
    expect(pill["class"].split).to include("bg-neutral-chip")
  end

  it "shows a warn pill when there is no Answer", :aggregate_failures do
    pill = render_row(create(:question)).at_css("[data-result]")

    expect(pill.text.strip).to eq("No answer")
    expect(pill["class"].split).to include("bg-warn-soft", "text-warn")
  end
end
