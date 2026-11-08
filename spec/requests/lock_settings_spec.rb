require "rails_helper"

RSpec.describe "Lock settings (on the profile)" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "shows the lock settings form on the profile" do
    get edit_profile_path
    expect(response.body).to include("Lock screen", "Current lock code or account password", "Save lock settings")
  end

  it "requires the current code or password" do
    patch lock_settings_path, params: { user: { auto_lock_minutes: 30 } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Enter your current lock code or account password", "Profile &amp; invoice details")
    patch lock_settings_path, params: { current_secret: "9999", user: { auto_lock_minutes: 30 } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.auto_lock_minutes).to eq(5)
  end

  it "changes the auto-lock period with the current code and keeps the code" do
    patch lock_settings_path, params: { current_secret: "2580", user: { lock_pin: "", lock_pin_confirmation: "", auto_lock_minutes: 30 } }
    expect(response).to redirect_to(edit_profile_path(anchor: "lock-screen"))
    expect(user.reload.auto_lock_minutes).to eq(30)
    expect(user.authenticate_lock_pin("2580")).to be_truthy
  end

  it "resets a forgotten code with the account password" do
    patch lock_settings_path, params: { current_secret: "password123", user: { lock_pin: "8642", lock_pin_confirmation: "8642", auto_lock_minutes: 5 } }
    expect(response).to redirect_to(edit_profile_path(anchor: "lock-screen"))
    expect(user.reload.authenticate_lock_pin("8642")).to be_truthy
  end

  it "rejects trivial or mismatched codes" do
    patch lock_settings_path, params: { current_secret: "2580", user: { lock_pin: "1234", lock_pin_confirmation: "1234" } }
    expect(response.body).to include("too easy to guess")
    patch lock_settings_path, params: { current_secret: "2580", user: { lock_pin: "2580", lock_pin_confirmation: "2581" } }
    expect(response.body).to include("doesn&#39;t match")
  end

  it "is not reachable while locked" do
    current_session_for(user).lock!
    patch lock_settings_path, params: { current_secret: "2580", user: { auto_lock_minutes: 30 } }
    expect(response).to redirect_to(lock_path)
    expect(user.reload.auto_lock_minutes).to eq(5)
  end
end
