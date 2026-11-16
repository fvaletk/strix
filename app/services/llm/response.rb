module Llm
  # content is a String, or a parsed Hash/Array when a schema was given.
  Response = Data.define(:content, :input_tokens, :output_tokens, :thinking_tokens)
end
