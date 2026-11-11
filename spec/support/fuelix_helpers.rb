module FuelixHelpers
  FUELIX_URL = "https://api.fuelix.ai/v1/chat/completions".freeze

  def with_fuelix_key(key = "test-key")
    ENV["FUELIX_API_KEY"] = key
    yield
  ensure
    ENV.delete("FUELIX_API_KEY")
  end

  def stub_fuelix(content: nil, status: 200, body: nil)
    body ||= { choices: [ { message: { content: content } } ] }.to_json
    stub_request(:post, FUELIX_URL).to_return(status:, body:, headers: { "Content-Type" => "application/json" })
  end

  def ai_payload(question_count: 5)
    {
      verse: { text: "This is the day.", reference: "Psalm 118:24", reflection: "Be glad today." },
      questions: Array.new(question_count) do |i|
        { category: "Cat #{i}", question: "Question #{i}?", choices: [ "Right #{i}", "B#{i}", "C#{i}", "D#{i}" ],
          answer_index: 0, explanation: "Because #{i}." }
      end
    }.to_json
  end
end

RSpec.configure { |config| config.include FuelixHelpers }

# Chat-with-tools replies for TimelogAgent: each argument is one FuelIX response, returned in order.
#   stub_fuelix_chat(tool_call("log_todo", todo: "Fix bug"), reply("Logged it.\n<suggestions>[\"Show today\"]</suggestions>"))
module FuelixChatHelpers
  def stub_fuelix_chat(*messages)
    responses = messages.map { |m| { status: 200, body: { choices: [ { message: m } ] }.to_json, headers: { "Content-Type" => "application/json" } } }
    stub_request(:post, FuelixHelpers::FUELIX_URL).to_return(*responses)
  end

  def tool_call(name, id: "call_#{name}", **args)
    { role: "assistant", content: nil, tool_calls: [ { id:, type: "function", function: { name:, arguments: args.to_json } } ] }
  end

  def reply(text) = { role: "assistant", content: text }

  # The JSON bodies FuelIX received, in order (each request differs, as the chat history grows).
  def fuelix_requests
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys
      .select { |r| r.uri.host == "api.fuelix.ai" && r.uri.path == "/v1/chat/completions" }
      .map { |r| JSON.parse(r.body) }
  end
end

RSpec.configure { |config| config.include FuelixChatHelpers }
