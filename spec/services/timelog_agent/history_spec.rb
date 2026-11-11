require "rails_helper"

RSpec.describe TimelogAgent::History do
  let(:conversation) { create(:conversation) }

  def add(role, **attrs) = conversation.messages.create!(role:, **attrs)

  it "replays the latest messages in the API format" do
    add("user", content: "Hi")
    add("assistant", tool_calls: [ { "id" => "c1", "type" => "function", "function" => { "name" => "get_account", "arguments" => "{}" } } ])
    add("tool", tool_call_id: "c1", content: "{}")
    add("assistant", content: "Hello")

    expect(described_class.new(conversation.messages).to_api.map { |m| m[:role] }).to eq(%w[user assistant tool assistant])
  end

  it "starts on a user message when older ones are cut off" do
    add("user", content: "First")
    add("assistant", tool_calls: [ { "id" => "c1" } ])
    add("tool", tool_call_id: "c1", content: "{}")
    add("assistant", content: "Done")
    add("user", content: "Second")

    replayed = described_class.new(conversation.messages, limit: 3).to_api
    expect(replayed).to eq([ { role: "user", content: "Second" } ])
  end
end
