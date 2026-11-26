class QuestionsController < ApplicationController
  def index
    @questions = current_user.questions.includes(answer: { answer_chunks: :chunk }).order(created_at: :desc, id: :desc)
  end

  def show
    @question = current_user.questions.find(params[:id])
  end

  def new
    @question = Question.new
    load_ask_context
  end

  def create
    @question = current_user.questions.build(question_params)
    unless @question.save
      load_ask_context
      return render :new, status: :unprocessable_entity
    end

    result = Questions::Respond.call(@question)
    flash[:alert] = "Couldn't answer this Question. Try again." if result.failure?
    redirect_to @question
  end

  private

  def load_ask_context
    @recent_questions = current_user.questions.includes(answer: { answer_chunks: :chunk }).order(created_at: :desc, id: :desc).limit(3)
    @articles_count = current_user.articles.count
  end

  def question_params
    params.expect(question: [ :text ])
  end
end
