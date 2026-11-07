require "rails_helper"

RSpec.describe "Onboarding and sign in" do
  it "signs up, sets a lock code, fills in the profile, and reaches the dashboard" do
    visit new_session_path
    click_on "Sign up"
    fill_in "Full name", with: "Jamie Rivera"
    fill_in "Email", with: "jamie@example.com"
    fill_in "Password (min 8 characters)", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_on "Sign up"

    expect(page).to have_content("Set up your lock screen")
    fill_in "Lock code", with: "2580"
    fill_in "Confirm lock code", with: "2580"
    select "15 minutes", from: "Lock automatically after inactivity"
    click_on "Turn on lock screen"

    expect(page).to have_content("Lock screen is on")
    expect(page).to have_content("Profile & invoice details")
    fill_in "Address", with: "1 Main St"
    fill_in "Hourly rate", with: "1000"
    click_on "Save"

    expect(page).to have_content("Profile saved.")
    expect(page).to have_content("Today's todo")
  end

  it "shows sign-up errors" do
    visit new_registration_path
    fill_in "Full name", with: "Jamie"
    fill_in "Email", with: "jamie@example.com"
    fill_in "Password (min 8 characters)", with: "password123"
    fill_in "Confirm password", with: "different1"
    click_on "Sign up"
    expect(page).to have_content("Password confirmation doesn't match")
  end

  it "rejects a wrong password and signs in with the right one, then signs out" do
    user = create(:user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "nope-nope"
    click_on "Sign in"
    expect(page).to have_content("Try another email address or password.")

    sign_in_ui(user)
    expect(page).to have_link("Dashboard")
    click_on "Sign out"
    expect(page).to have_button("Sign in")
  end

  it "lets a user change lock settings from the profile" do
    user = create(:user)
    sign_in_ui(user)
    click_on user.name
    expect(page).to have_content("Locks automatically after 5 minutes")
    click_on "Change lock settings"
    fill_in "Current lock code or account password", with: "2580"
    select "Never", from: "Lock automatically after inactivity"
    click_on "Save"
    expect(page).to have_content("Lock screen settings saved.")
    expect(page).to have_content("Auto-lock is off")
  end
end
