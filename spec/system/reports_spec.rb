require "rails_helper"

RSpec.describe "Export report" do
  let(:user) { create(:user) }

  before do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "November work")
    create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "October work")
  end

  it "previews the selected period" do
    sign_in_ui(user)
    click_on "Export report"
    expect(page).to have_content("Preview: November 2026")
    expect(page).to have_content("November work")
    select "Previous month", from: "Period"
    click_on "Show entries"
    expect(page).to have_content("Preview: October 2026")
    expect(page).to have_content("October work")
  end

  it "shows only the fields for the chosen period", :js do
    sign_in_ui(user)
    click_on "Export report"
    expect(page).to have_no_field("count")
    select "Last N weeks", from: "Period"
    expect(page).to have_field("count")
    expect(page).to have_content("Number of weeks")
    select "Custom date range", from: "Period"
    expect(page).to have_field("from").and have_field("to")
    expect(page).to have_no_field("count")
    fill_in "from", with: "2026-10-01"
    fill_in "to", with: "2026-10-31"
    click_on "Show entries"
    expect(page).to have_content("Preview: 01 Oct 2026 – 31 Oct 2026")
  end

  it "opens the PDF preview modal with the current period", :js do
    sign_in_ui(user)
    click_on "Export report"
    select "Previous month", from: "Period"
    click_on "Preview PDF"
    within("dialog.pdf-modal[open]") do
      expect(page).to have_content("Time.log report")
      expect(find("iframe", visible: :all)[:src]).to include("/reports/export", "period=previous_month", "inline=1")
      expect(find_link("Download PDF")[:href]).to include("period=previous_month")
      click_on "Close"
    end
    expect(page).to have_no_css("dialog.pdf-modal[open]")
  end
end
