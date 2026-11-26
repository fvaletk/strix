class QuestionPresenter < SimpleDelegator
  def result
    return :no_answer unless answer
    return :nothing_found if AnswerPresenter.new(answer).nothing_found?

    :cited
  end

  def result_label
    case result
    when :no_answer then "No answer"
    when :nothing_found then "Nothing found"
    else "#{cited_count} #{"Article".pluralize(cited_count)} cited"
    end
  end

  def asked_on
    created_at.strftime("%b %-d, %Y")
  end

  private

  def cited_count
    answer.answer_chunks.select(&:cited).map { |ac| ac.chunk.article_id }.uniq.size
  end
end
