require "rails_helper"

RSpec.describe "Onboarding and sign in" do
  it "signs up, fills in invoice details, sets a lock code, and reaches the dashboard" do
    visit new_session_path
    click_on "Sign up"
    fill_in "Full name", with: "Jamie Rivera"
    fill_in "Email", with: "jamie@example.com"
    fill_in "Password (min 8 characters)", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_on "Sign up"

    expect(page).to have_content("Welcome!")
    expect(page).to have_content("Your invoice details")
    expect(page).to have_no_css("aside.sidebar")
    fill_in "Address", with: "1 Main St"
    fill_in "Client name", with: "Acme Ltd"
    fill_in "Client address", with: "1 Client Way\nLondon"
    expect(page).to have_field("Item (shown on the invoice line)", with: "Consultancy Service")
    fill_in "Item (shown on the invoice line)", with: "Software Development"
    fill_in "Hourly rate", with: "1000"
    fill_in "Account name", with: "Jamie Rivera"
    fill_in "Account number", with: "0012345678"
    fill_in "Bank name", with: "BDO"
    fill_in "SWIFT", with: "BNORPHMM"
    click_on "Continue"

    expect(page).to have_content("Set up your lock screen")
    fill_in "Lock code", with: "2580"
    fill_in "Confirm lock code", with: "2580"
    select "15 minutes", from: "Lock automatically after inactivity"
    click_on "Finish setup"

    expect(page).to have_content("You're all set")
    expect(page).to have_content("Today's todo")
    expect(User.last).to have_attributes(onboarded?: true, auto_lock_minutes: 15, bank_name: "BDO", bill_to_name: "Acme Ltd", invoice_item: "Software Development")
  end

  it "can go back from the lock step to the invoice details" do
    sign_in_onboarding(create(:user, :without_lock))
    expect(page).to have_content("Set up your lock screen")
    click_on "Back"
    expect(page).to have_field("Bank name", with: "BDO")
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
    fill_in "Current lock code or account password", with: "2580"
    select "Never", from: "Lock automatically after inactivity"
    click_on "Save lock settings"
    expect(page).to have_content("Lock screen settings saved.")
    expect(page).to have_content("Auto-lock is off")
  end

  def sign_in_onboarding(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password123"
    click_on "Sign in"
  end
end
