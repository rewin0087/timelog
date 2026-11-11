require "rails_helper"

RSpec.describe "Assistant conversations" do
  let(:user) { create(:user) }

  before { sign_in(user) }
  around { |example| with_fuelix_key { example.run } }

  it "shows a new chat with starter suggestions" do
    get conversations_path
    expect(response.body).to include("what are you working on?", "Log what I worked on today")
  end

  it "starts a conversation and shows the exchange" do
    stub_fuelix_chat(reply("Hi! Nothing logged yet today.\n<suggestions>[\"Log a todo\"]</suggestions>"))
    post conversations_path, params: { message: "Hello" }

    conversation = user.conversations.last
    expect(response).to redirect_to(conversation_path(conversation))
    follow_redirect!
    expect(response.body).to include("Hello", "Nothing logged yet today.", "Log a todo")
  end

  it "replies in an existing conversation with a turbo stream" do
    conversation = create(:conversation, user:)
    stub_fuelix_chat(reply("Sure thing."))
    post conversation_messages_path(conversation), params: { message: "Again" }, as: :turbo_stream

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="chat-pending"', "Again", "Sure thing.")
  end

  it "shows an error in the thread when the assistant is down" do
    conversation = create(:conversation, user:)
    stub_request(:post, FuelixHelpers::FUELIX_URL).to_return(status: 503)
    post conversation_messages_path(conversation), params: { message: "Hi" }, as: :turbo_stream
    expect(response.body).to include("chat-msg-error", "unavailable")
  end

  it "keeps other users' conversations private" do
    other = create(:conversation)
    get conversation_path(other)
    expect(response).to have_http_status(:not_found)
    post conversation_messages_path(other), params: { message: "Hi" }, as: :turbo_stream
    expect(response).to have_http_status(:not_found)
  end

  it "deletes a conversation" do
    conversation = create(:conversation, user:)
    delete conversation_path(conversation)
    expect(response).to redirect_to(conversations_path)
    expect(user.conversations).to be_empty
  end

  describe "dashboard shortcut" do
    it "offers the assistant with suggestions from the user's data, starting a chat from a chip" do
      create(:daily_inspiration)
      get root_path
      expect(response.body).to include("hero-panel-assistant", "Log what I worked on today", "Open the chat")

      stub_fuelix_chat(reply("Sure, what did you work on?"))
      post conversations_path, params: { message: "Help me log what I worked on today." }
      expect(response).to redirect_to(conversation_path(user.conversations.last))
    end
  end

  it "shows prepared documents under the reply without saving anything" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    conversation = create(:conversation, user:)
    stub_fuelix_chat(tool_call("prepare_invoice"), tool_call("export_report", id: "c2"), reply("Both are ready below."))
    post conversation_messages_path(conversation), params: { message: "Invoice and report for this month" }, as: :turbo_stream

    expect(user.invoices).to be_empty
    expect(response.body).to include("Draft invoice INV-001 · November 2026", "not saved yet", "Time log report · November 2026")
    expect(response.body).to include(%(data-pdf-preview-url-param="/invoice_drafts/2026-11"), %(data-pdf-preview-save-url-param="/invoice_drafts/2026-11"))
    expect(response.body).to include(%(action="/invoice_drafts/2026-11"), %(href="#{ERB::Util.h(export_report_path(period: "month", month: "2026-11"))}"))
  end
end
