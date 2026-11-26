require "rails_helper"

# rubocop:disable RSpec/ExampleLength

RSpec.describe "Questions", type: :request do
  let!(:user) { create(:user) }

  describe "GET /questions/new" do
    it "shows the ask form", :aggregate_failures do
      get "/questions/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="/questions"')
    end
  end

  describe "POST /questions" do
    let(:client) { instance_double(Llm::Client) }
    let(:params) { { question: { text: "What do bees make?" } } }

    before { allow(Llm::Client).to receive(:new).and_return(client) }

    context "when answering succeeds" do
      before do
        article = create(:article, :ready, user:, title: "Bees")
        create(:chunk, article:, embedding: Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 })
        allow(client).to receive_messages(
          embed: [ Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 } ],
          generate: Llm::Response.new(content: "Honey [1].", input_tokens: 1, output_tokens: 1, thinking_tokens: 0)
        )
      end

      it "saves the Question and Answer and redirects to the Question", :aggregate_failures do
        expect { post "/questions", params: }.to change(Question, :count).by(1).and change(Answer, :count).by(1)
        expect(response).to redirect_to(question_path(Question.last))
        expect(Question.last.user).to eq(user)
      end
    end

    context "when Llm::Client raises Llm::Error" do
      before { allow(client).to receive(:embed).and_raise(Llm::Error.new("boom")) }

      it "keeps the Question, saves no Answer and flashes the failure", :aggregate_failures do
        expect { post "/questions", params: }.to change(Question, :count).by(1)
        expect(Answer.count).to eq(0)
        expect(response).to redirect_to(question_path(Question.last))
        expect(flash[:alert]).to eq("Couldn't answer this Question. Try again.")
        follow_redirect!
        expect(response.body).to include("Couldn&#39;t answer this Question. Try again.", "No answer yet.")
      end
    end

    context "when the text is blank" do
      it "re-renders the form without saving", :aggregate_failures do
        expect { post "/questions", params: { question: { text: "" } } }.not_to change(Question, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /questions/:id" do
    it "shows the Question, the Answer and links to cited Articles only", :aggregate_failures do
      question = create(:question, user:, text: "What do bees make?")
      answer = create(:answer, question:, text: "Honey [1].")
      cited = create(:chunk, article: create(:article, :ready, title: "Bees"))
      uncited = create(:chunk, article: create(:article, :ready, title: "Wasps"))
      create(:answer_chunk, :cited, answer:, chunk: cited, rank: 1)
      create(:answer_chunk, answer:, chunk: uncited, rank: 2)

      get "/questions/#{question.id}"
      expect(response.body).to include("What do bees make?", "Honey [1].", "Bees", article_path(cited.article))
      expect(response.body).not_to include("Wasps")
    end

    it "says there is no answer yet when the Question has none" do
      question = create(:question, user:)
      get "/questions/#{question.id}"
      expect(response.body).to include("No answer yet.")
    end

    it "does not show another User's Question" do
      other = create(:question)
      get "/questions/#{other.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /questions" do
    it "lists the User's Questions newest first", :aggregate_failures do
      create(:question, user:, text: "Older one", created_at: 2.days.ago)
      create(:question, user:, text: "Newer one", created_at: 1.day.ago)
      create(:question, text: "Someone else's")
      get "/questions"
      expect(response.body.index("Newer one")).to be < response.body.index("Older one")
      expect(response.body).not_to include("Someone else's")
    end
  end
end
