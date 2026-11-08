require "rails_helper"

RSpec.describe "Working hours settings" do
  let(:user) { create(:user, :invoice_ready) }

  it "sets a custom monthly target from the profile" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Work")
    sign_in_ui(user)
    click_on user.name
    expect(page).to have_checked_field("Fixed monthly target")
    fill_in "Monthly target hours (leave blank for 160)", with: "168"
    click_on "Save profile"
    expect(page).to have_content("Profile saved. Hours on your logs were recalculated.")
    expect(page).to have_content("168h ÷ 21 weekdays = 8h per day")
    expect(page).to have_content("21 weekdays · 168h target")
  end

  it "switches to no monthly target and bills logged hours", :js do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 1), todo: "Work")
    sign_in_ui(user)
    click_on user.name
    expect(page).to have_field("Monthly target hours (leave blank for 160)")
    choose "No monthly target"
    expect(page).to have_no_field("Monthly target hours (leave blank for 160)")
    click_on "Save profile"
    expect(page).to have_content("No monthly target: each logged weekday counts 8h")

    click_on "Invoices"
    expect(page).to have_content("Bills the hours you logged")
    select "October 2026", from: "period"
    click_on "Generate invoice"
    within("table.rtable tbody tr", text: "INV-001") { expect(page).to have_content("8.00") }
  end
end
