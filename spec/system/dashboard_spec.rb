require "rails_helper"

RSpec.describe "Dashboard" do
  let(:user) { create(:user) }

  it "quick-adds a todo for today and shows it in this week" do
    sign_in_ui(user)
    fill_in placeholder: "What are you working on today?", with: "Write system specs"
    click_on "Log it"
    expect(page).to have_content("Logged for 13 Nov 2026.")
    within("table.rtable") { expect(page).to have_content("Write system specs").and have_content("7.62") }
  end

  it "switches between week and month views and pages through months" do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 5), todo: "October work")
    sign_in_ui(user)
    click_on "Month report"
    expect(page).to have_css("h2", text: "November 2026")
    click_on "← Previous"
    expect(page).to have_css("h2", text: "October 2026")
    expect(page).to have_content("October work")
    click_on "Week"
    expect(page).to have_content("This week (09 Nov – 15 Nov)")
  end

  it "shows month progress, the last 3 months, and holidays" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Public holiday")
    create(:time_entry, user:, log_date: Date.new(2026, 11, 3), todo: "Work")
    sign_in_ui(user)
    expect(page).to have_content("November 2026 progress")
    expect(page).to have_content("Hours left to log")
    expect(page).to have_content("Last 3 months")
    expect(page).to have_css(".hbar-row", text: "Nov 2026")
    within(".chart-legend", match: :first) { expect(page).to have_content("Public holiday") }
  end

  context "with JavaScript", :js do
    it "shows a tooltip when hovering a day in the chart" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Work")
      sign_in_ui(user)
      wait_for_animations
      column = find(".chart-dense .chart-col[aria-label^='Mon, 2 Nov']")
      expect(column).to have_css(".chart-tip", visible: :hidden)
      column.hover
      expect(column).to have_css(".chart-tip", visible: :visible, text: "7.62h · 1 activity")
    end

    it "loads the daily verse and plays trivia, remembering progress after reload" do
      create(:daily_inspiration, day: Date.current)
      sign_in_ui(user)
      within(".trivia-card") do
        expect(page).to have_content("What is the chemical symbol for gold?")
        expect(page).to have_content("Pick an answer")
        click_on "Au"
        expect(page).to have_content("Correct!")
        expect(page).to have_content("Score: 1/1")
        click_on "Next question →"
        expect(page).to have_content("How many hearts does an octopus have?")
        click_on "One"
        expect(page).to have_content("Not quite — it's Three.")
        expect(page).to have_content("Final score: 1/2")
      end
      expect(page).to have_content("Colossians 3:23")

      visit root_path
      within(".trivia-card") { expect(page).to have_content("Final score: 1/2") }
    end
  end
end
