class TimelogAgent
  # Saves a conversation's chat log as it happens: the user's messages, the model's tool calls,
  # each tool's result, and the final reply with its suggestions.
  class Transcript
    def initialize(conversation)
      @conversation = conversation
    end

    # The first message also names the conversation.
    def record_user(text)
      conversation.title_from(text)
      messages.create!(role: "user", content: text)
    end

    def record_tool_calls(content, calls) = messages.create!(role: "assistant", content: content.presence, tool_calls: calls)

    def record_tool_result(call_id, result) = messages.create!(role: "tool", tool_call_id: call_id, content: result.to_json)

    def record_reply(reply, attachments: [])
      messages.create!(role: "assistant", content: reply.text, suggestions: reply.suggestions, attachments: attachments.uniq)
    end

    private

    attr_reader :conversation

    def messages = conversation.messages
  end
end
