require "rails_helper"

RSpec.describe "Sidebar", js: true do
  let(:user) { create(:user) }

  it "collapses to an icon rail and remembers it across page loads" do
    sign_in_ui(user)
    expect(page).to have_css("body:not(.sidebar-collapsed)")

    click_on "Collapse sidebar"
    expect(page).to have_css("body.sidebar-collapsed")
    expect(page).to have_button("Expand sidebar")

    visit time_entries_path
    expect(page).to have_css("body.sidebar-collapsed")

    click_on "Expand sidebar"
    expect(page).to have_css("body:not(.sidebar-collapsed)")
    visit root_path
    expect(page).to have_css("body:not(.sidebar-collapsed)")
  end
end
