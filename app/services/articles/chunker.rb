module Articles
  # Pure splitter: text in, overlapping chunk strings out. Splits by words; prefers paragraph
  # and sentence boundaries, and only splits inside a sentence when it is longer than a chunk.
  class Chunker
    def self.call(...) = new(...).call

    def initialize(text, words:, overlap_words:)
      @text = text.to_s
      @words = words
      @overlap_words = overlap_words
    end

    def call
      chunks = []
      current = []
      fresh = 0
      units.each do |unit|
        if fresh.positive? && current.size + unit.size > @words
          chunks << current.join(" ")
          current = current.last([ @overlap_words, @words - unit.size ].min.clamp(0, @words))
          fresh = 0
        end
        current += unit
        fresh += unit.size
      end
      chunks << current.join(" ") if fresh.positive?
      chunks
    end

    private

    # Sentence-sized arrays of words, none longer than a chunk.
    def units
      @text.split(/\n\s*\n/).flat_map { |paragraph| paragraph.split(/(?<=[.!?])\s+/) }
           .map(&:split).reject(&:empty?)
           .flat_map { |sentence| sentence.each_slice(@words).to_a }
    end
  end
end
