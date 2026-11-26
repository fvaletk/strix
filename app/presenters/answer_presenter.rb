class AnswerPresenter < SimpleDelegator
  MARKER = /\A\[(\d+)\]\z/

  # [[Article, number], ...] — each cited Article once, numbered from 1.
  def sources
    @sources ||= cited_articles.each.with_index(1).to_a
  end

  # Paragraphs of segments: a String is plain text, an Integer is a citation marker
  # pointing at that source number. Markers with no cited Chunk stay as text.
  def paragraphs
    text.split(/\n{2,}/).map { |paragraph| segments(paragraph) }
  end

  def nothing_found?
    text.strip == Questions::Respond::NOTHING_FOUND
  end

  private

  def segments(paragraph)
    paragraph.split(/(\[\d+\])/).reject(&:empty?).map do |part|
      rank = part[MARKER, 1]
      (rank && source_number(rank.to_i)) || part
    end
  end

  def source_number(rank)
    article_id = cited_article_ids_by_rank[rank]
    return unless article_id

    sources.find { |article, _| article.id == article_id }&.last
  end

  def cited_article_ids_by_rank
    @cited_article_ids_by_rank ||= answer_chunks.where(cited: true).includes(:chunk).to_h { |ac| [ ac.rank, ac.chunk.article_id ] }
  end
end
