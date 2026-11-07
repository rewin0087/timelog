require "rails_helper"

RSpec.describe "Mobile layout", :js, :mobile do
  let(:user) { create(:user) }

  it "moves skins and sign out into the avatar menu" do
    sign_in_ui(user)
    expect(page).to have_no_button("Sign out")
    find("button[aria-label='Account and skins']").click
    expect(page).to have_button("Sign out")
    expect(page).to have_css("button[aria-label='Ocean skin']")
    find("main").click
    expect(page).to have_no_button("Sign out")
  end

  it "shows the dashboard charts without horizontal scrolling" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    sign_in_ui(user)
    expect(page).to have_content("November 2026 progress")
    wait_for_animations
    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    expect(overflow).to be <= 0
    wide = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".mini-table-wrap")].filter(w => w.scrollWidth > w.clientWidth + 1).length
    JS
    expect(wide).to eq(0), "a dashboard table needs horizontal scrolling on a phone"
  end
end
