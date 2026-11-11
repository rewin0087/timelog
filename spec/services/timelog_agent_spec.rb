require "rails_helper"

RSpec.describe TimelogAgent, at: Time.zone.local(2026, 11, 11, 10) do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user:) }
  let(:today) { Date.new(2026, 11, 11) }

  around { |example| with_fuelix_key { example.run } }

  it "runs the tools the model asks for, then saves its reply and suggestions" do
    stub_fuelix_chat(
      tool_call("log_todo", todo: "Fixed the login bug"),
      reply("Logged **Fixed the login bug** for today.\n<suggestions>[\"What else did I log today?\", \"Hours left this month?\"]</suggestions>")
    )

    message = described_class.new(conversation).reply("I fixed the login bug")

    expect(user.time_entries.pluck(:log_date, :todo)).to eq([ [ today, "Fixed the login bug" ] ])
    expect(message.content).to eq("Logged **Fixed the login bug** for today.")
    expect(message.suggestions).to eq([ "What else did I log today?", "Hours left this month?" ])
    expect(conversation.reload.title).to eq("I fixed the login bug")
    expect(conversation.messages.pluck(:role)).to eq(%w[user assistant tool assistant])
    expect(conversation.visible_messages.map(&:role)).to eq(%w[user assistant])
  end

  it "sends today's date, the tools, and the whole conversation so far" do
    stub_fuelix_chat(reply("Hello!"), reply("You asked about hours."))
    agent = described_class.new(conversation)
    agent.reply("Hi")
    agent.reply("What did I just ask?")

    first, second = fuelix_requests
    expect(first["messages"].first).to include("role" => "system")
    expect(first["messages"].first["content"]).to include("Wednesday, 11 November 2026", user.name)
    expect(first["tools"].map { |t| t.dig("function", "name") }).to include("log_todo", "list_time_entries", "month_summary", "list_invoices", "get_account")
    expect(second["messages"].drop(1)).to eq([
      { "role" => "user", "content" => "Hi" },
      { "role" => "assistant", "content" => "Hello!" },
      { "role" => "user", "content" => "What did I just ask?" }
    ])
  end

  it "replays earlier tool calls and results when a conversation is picked up again" do
    stub_fuelix_chat(tool_call("month_summary", month: "2026-11"), reply("You're on track."), reply("Sure."))
    described_class.new(conversation).reply("How's this month?")
    described_class.new(conversation.reload).reply("Thanks")

    replayed = fuelix_requests.last["messages"].drop(1).map { |m| m["role"] }
    expect(replayed).to eq(%w[user assistant tool assistant user])
  end

  it "keeps the user's message and raises a friendly error when FuelIX fails" do
    stub_request(:post, FuelixHelpers::FUELIX_URL).to_return(status: 500)

    expect { described_class.new(conversation).reply("Hi") }.to raise_error(TimelogAgent::Error, /unavailable/)
    expect(conversation.messages.pluck(:role, :content)).to eq([ %w[user Hi] ])
  end

  it "stops after a few tool rounds instead of looping forever" do
    stub_fuelix_chat(tool_call("get_account"))
    message = described_class.new(conversation).reply("Loop")
    expect(message.content).to match(/couldn't finish/)
    expect(fuelix_requests.size).to eq(TimelogAgent::MAX_TOOL_ROUNDS)
  end
end
