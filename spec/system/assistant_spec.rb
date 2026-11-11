require "rails_helper"

RSpec.describe "Assistant chat", js: true do
  let(:user) { create(:user) }
  before { create(:daily_inspiration) } # the dashboard would otherwise ask FuelIX for one

  around { |example| with_fuelix_key { example.run } }

  it "chats, logs a todo, offers follow-ups, and keeps the conversation" do
    stub_fuelix_chat(
      tool_call("log_todo", todo: "Fixed the login bug"),
      reply("Logged **Fixed the login bug** for today.\n<suggestions>[\"What did I log today?\"]</suggestions>"),
      reply("| Date | Todo | Hours |\n|---|---|---|\n| Fri, 13 Nov | Fixed the login bug | 7.62 |\n<suggestions>[\"Hours left this month?\"]</suggestions>")
    )
    sign_in_ui(user)
    within(".sidebar nav") { click_on "Assistant" }

    fill_in placeholder: "Message the assistant…", with: "I fixed the login bug"
    find(".chat-send").click
    expect(page).to have_css(".chat-msg-assistant", text: "Logged Fixed the login bug for today.")
    expect(user.time_entries.pluck(:todo)).to eq([ "Fixed the login bug" ])

    click_on "What did I log today?"
    within(".chat-table") { expect(page).to have_content("Fixed the login bug") }
    expect(page).to have_button("Hours left this month?")

    visit conversations_path
    within("#chat-list") { click_on "I fixed the login bug" }
    expect(page).to have_css(".chat-msg-user", count: 2)
    expect(page).to have_css(".chat-msg-assistant", count: 2)
  end

  it "switches the dashboard card between today's todo and the assistant, and remembers the tab" do
    sign_in_ui(user)
    expect(page).to have_field(placeholder: "What are you working on today?")
    expect(page).to have_no_field(placeholder: "Tell me what you did, or ask about your hours and invoices")

    find("#hero-tab-assistant").click
    expect(page).to have_field(placeholder: "Tell me what you did, or ask about your hours and invoices")
    visit root_path
    expect(page).to have_field(placeholder: "Tell me what you did, or ask about your hours and invoices")

    find(".hero-settings summary").click
    click_on "Today's todo only"
    expect(page).to have_content("Dashboard now shows: Today's todo only.")
    expect(page).to have_no_css("[role=tab]")
  end

  it "previews a draft invoice without saving it; only Download saves it" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    conversation = create(:conversation, user:, title: "Invoice")
    conversation.messages.create!(role: "user", content: "Invoice please")
    conversation.messages.create!(role: "assistant", content: "Here's a draft.", attachments: [ { "kind" => "invoice_draft", "month" => "2026-11", "refresh" => false } ])
    sign_in_ui(user)
    page.driver.resize(1400, 900)
    visit conversation_path(conversation)

    within(".chat-doc") { click_on "Preview" }
    within("dialog.pdf-modal") { expect(page).to have_link("Save & download") }
    expect(user.invoices.count).to eq(0)
    within("dialog.pdf-modal") { click_on "Close" }

    within(".chat-doc") { click_on "Download" }
    50.times { break if user.invoices.exists?; sleep 0.1 } # the download doesn't change the page
    expect(user.invoices.count).to eq(1)
  end
end
