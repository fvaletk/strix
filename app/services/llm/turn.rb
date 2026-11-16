module Llm
  # One model turn from Client#chat: text, tool calls, or both.
  #
  # provider_content is opaque: the model's raw reply, which carries provider data (such as
  # thought signatures) that must be sent back unchanged. Callers never inspect it; they append
  # #to_message to their messages and the client reproduces the turn.
  Turn = Data.define(:text, :tool_calls, :provider_content, :input_tokens, :output_tokens, :thinking_tokens) do
    def tool_calls? = tool_calls.any?

    def to_message = { role: :assistant, text:, tool_calls:, provider_content: }
  end
end
