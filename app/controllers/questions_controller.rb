class QuestionsController < ApplicationController
  def index
    @questions = current_user.questions.order(created_at: :desc, id: :desc)
  end

  def show
    @question = current_user.questions.find(params[:id])
  end

  def new
    @question = Question.new
  end

  def create
    @question = current_user.questions.build(question_params)
    return render :new, status: :unprocessable_entity unless @question.save

    result = Questions::Respond.call(@question)
    flash[:alert] = "Couldn't answer this Question. Try again." if result.failure?
    redirect_to @question
  end

  private

  def question_params
    params.expect(question: [ :text ])
  end
end
