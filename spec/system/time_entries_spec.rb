require "rails_helper"

RSpec.describe "Manage logs" do
  let(:user) { create(:user) }

  it "creates, edits, and lists entries with automatic hours" do
    sign_in_ui(user)
    click_on "Manage logs"
    click_on "+ New timelog"
    fill_in "Date", with: "2026-11-09"
    fill_in "Todo", with: "Plan sprint"
    click_on "Create Time entry"
    expect(page).to have_content("Timelog created.")
    expect(page).to have_content("Plan sprint")
    expect(page).to have_content("7.62")

    click_on "Edit"
    fill_in "Todo", with: "Plan sprint 42"
    click_on "Update Time entry"
    expect(page).to have_content("Timelog updated.")
    expect(page).to have_content("Plan sprint 42")
  end

  it "shows validation errors" do
    sign_in_ui(user)
    visit new_time_entry_path
    fill_in "Date", with: "2026-11-09"
    fill_in "Todo", with: ""
    page.execute_script("document.querySelector('form').noValidate = true") if page.driver.respond_to?(:browser) && Capybara.current_driver != :rack_test
    click_on "Create Time entry"
    expect(page).to have_content("Todo can't be blank")
  end

  it "shows this month's and all-time stats and charts" do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 1), todo: "Standup")
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Standup")
    sign_in_ui(user)
    click_on "Manage logs"
    within(".stat-split", text: "Activities logged") do
      expect(page).to have_css(".stat-value", text: "1")
      expect(page).to have_css(".split-value", text: "2")
      expect(page).to have_content("All time")
    end
    expect(page).to have_content("Hours per month")
    expect(page).to have_css(".heat-cell")
    within(".hbars-wide") { expect(page).to have_content("Standup").and have_content("2×") }
  end

  it "pages through older entries" do
    stub_const("TimeEntriesController::PER_PAGE", 2)
    5.times { |i| create(:time_entry, user:, log_date: Date.new(2026, 11, 2) + i, todo: "Entry #{i + 1}") }
    sign_in_ui(user)
    click_on "Manage logs"
    expect(page).to have_content("Showing 1–2 of 5 entries")
    expect(page).to have_content("Entry 5")
    click_on "Older →"
    expect(page).to have_content("Showing 3–4 of 5 entries")
    expect(page).to have_content("Entry 3")
    expect(page).to have_no_content("Entry 5")
    within(".pager-links") { click_link "3" }
    expect(page).to have_content("Entry 1")
    expect(page).to have_css(".pager-links .disabled", text: "Older →")
    click_on "← Newer"
    expect(page).to have_content("Showing 3–4 of 5 entries")
  end

  it "deletes an entry after confirming", :js do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 9), todo: "Delete me")
    sign_in_ui(user)
    click_on "Manage logs"
    accept_confirm("Delete this timelog?") { click_on "Delete" }
    expect(page).to have_content("Timelog deleted.")
    expect(page).not_to have_content("Delete me")
  end
end
