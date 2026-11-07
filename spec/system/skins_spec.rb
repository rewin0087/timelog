require "rails_helper"

RSpec.describe "Skins", :js do
  it "switches skin instantly and keeps it after reload, until sign out" do
    user = create(:user)
    sign_in_ui(user)
    expect(page).to have_css("body[data-theme='violet']")

    find("button[aria-label='Ocean skin']").click
    expect(page).to have_css("body[data-theme='ocean']")
    expect(page).to have_css("button.active[aria-label='Ocean skin']")

    visit root_path
    expect(page).to have_css("body[data-theme='ocean']")

    click_on "Sign out"
    sign_in_ui(user)
    expect(page).to have_css("body[data-theme='violet']")
  end
end
