module Llm
  class Error < StandardError
    def initialize(message = nil, retryable: false)
      super(message)
      @retryable = retryable
    end

    def retryable? = @retryable
  end
end
