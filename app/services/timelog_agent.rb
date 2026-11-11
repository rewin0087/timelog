# The timelog assistant: a chat agent that logs todos, lists time logs, and answers questions about the
# user's account, hours, and invoices. This class only runs the conversation loop; the parts live in
# TimelogAgent::* -
#
#   SystemPrompt  the instructions (template: timelog_agent/system_prompt.md.erb)
#   History       which saved messages are replayed to the model
#   Transcript    saving the chat log (user messages, tool calls and results, replies)
#   Reply         splitting a reply into its text and follow-up suggestions
#   Toolbox       the tools the model can call (one class each under Tools::)
#
#   TimelogAgent.new(conversation).reply("Log: fixed the login bug") # => the assistant's ChatMessage
class TimelogAgent
  class Error < StandardError; end

  MAX_TOOL_ROUNDS = 6 # model -> tools -> model ... before giving up on a reply
  GAVE_UP = "I couldn't finish that in one go. Could you narrow it down, for example to one month?"
  UNAVAILABLE = "The assistant is unavailable right now. Please try again in a moment."

  def self.available? = FuelixClient.configured?

  def initialize(conversation, client: FuelixClient.new, today: Date.current)
    @conversation = conversation
    @client = client
    @transcript = Transcript.new(conversation)
    @toolbox = Toolbox.new(conversation.user, today:)
    @system_prompt = SystemPrompt.new(conversation.user, today:).to_s
  end

  # Saves the user's message, lets the model call tools until it answers, and returns the saved reply.
  # Raises TimelogAgent::Error when the model can't be reached; the user's message is kept either way.
  def reply(text)
    transcript.record_user(text)
    toolbox.attachments.clear

    MAX_TOOL_ROUNDS.times do
      message = client.chat(model_messages, tools: Toolbox.definitions)
      calls = Array(message["tool_calls"])
      return transcript.record_reply(Reply.parse(message["content"]), attachments: toolbox.attachments) if calls.empty?

      run_tools(message["content"], calls)
    end
    transcript.record_reply(Reply.new(text: GAVE_UP, suggestions: []), attachments: toolbox.attachments)
  rescue FuelixClient::Error => e
    Rails.logger.warn("[TimelogAgent] #{e.message}")
    raise Error, UNAVAILABLE
  end

  private

  attr_reader :conversation, :client, :transcript, :toolbox, :system_prompt

  def model_messages = [ { role: "system", content: system_prompt }, *History.new(conversation.messages).to_api ]

  def run_tools(content, calls)
    transcript.record_tool_calls(content, calls)
    calls.each do |call|
      result = toolbox.call(call.dig("function", "name"), call.dig("function", "arguments"))
      transcript.record_tool_result(call["id"], result)
    end
  end
end
