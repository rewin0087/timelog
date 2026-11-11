require "rails_helper"

RSpec.describe TimelogAgent::Transcript do
  let(:conversation) { create(:conversation) }
  let(:transcript) { described_class.new(conversation) }

  it "saves each step of an exchange and names the conversation after the first message" do
    transcript.record_user("Log my standup")
    transcript.record_user("Second message")
    transcript.record_tool_calls("", [ { "id" => "c1" } ])
    transcript.record_tool_result("c1", { ok: true })
    transcript.record_reply(TimelogAgent::Reply.new(text: "Logged.", suggestions: [ "Next?" ]))

    expect(conversation.reload.title).to eq("Log my standup")
    expect(conversation.messages.map { |m| [ m.role, m.content, m.tool_call_id ] }).to eq([
      [ "user", "Log my standup", nil ], [ "user", "Second message", nil ], [ "assistant", nil, nil ],
      [ "tool", '{"ok":true}', "c1" ], [ "assistant", "Logged.", nil ]
    ])
    expect(conversation.suggestions).to eq([ "Next?" ])
  end
end
