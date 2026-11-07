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
