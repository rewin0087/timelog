require "rails_helper"

RSpec.describe "Lock settings" do
  context "first-time setup" do
    let(:user) { create(:user, :without_lock) }

    before { sign_in(user) }

    it "shows the setup form" do
      get edit_lock_settings_path
      expect(response.body).to include("Set up your lock screen", "Turn on lock screen")
    end

    it "saves a valid code and continues to the page that was blocked" do
      get invoices_path
      patch lock_settings_path, params: { user: { lock_pin: "2580", lock_pin_confirmation: "2580", auto_lock_minutes: 15 } }
      expect(response).to redirect_to(invoices_url)
      expect(flash[:notice]).to start_with("Lock screen is on")
      expect(user.reload).to have_attributes(lock_configured?: true, auto_lock_minutes: 15)
    end

    it "requires a code" do
      patch lock_settings_path, params: { user: { lock_pin: "", lock_pin_confirmation: "", auto_lock_minutes: 5 } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Lock code can&#39;t be blank")
    end

    it "rejects trivial or mismatched codes" do
      patch lock_settings_path, params: { user: { lock_pin: "1234", lock_pin_confirmation: "1234" } }
      expect(response.body).to include("too easy to guess")
      patch lock_settings_path, params: { user: { lock_pin: "2580", lock_pin_confirmation: "2581" } }
      expect(response.body).to include("doesn&#39;t match")
    end
  end

  context "changing settings" do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it "requires the current code or password" do
      patch lock_settings_path, params: { user: { auto_lock_minutes: 30 } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Enter your current lock code or account password")
      patch lock_settings_path, params: { current_secret: "9999", user: { auto_lock_minutes: 30 } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "changes the auto-lock period with the current code and keeps the code" do
      patch lock_settings_path, params: { current_secret: "2580", user: { lock_pin: "", lock_pin_confirmation: "", auto_lock_minutes: 30 } }
      expect(response).to redirect_to(edit_profile_path)
      expect(user.reload.auto_lock_minutes).to eq(30)
      expect(user.authenticate_lock_pin("2580")).to be_truthy
    end

    it "resets a forgotten code with the account password" do
      patch lock_settings_path, params: { current_secret: "password123", user: { lock_pin: "8642", lock_pin_confirmation: "8642", auto_lock_minutes: 5 } }
      expect(response).to redirect_to(edit_profile_path)
      expect(user.reload.authenticate_lock_pin("8642")).to be_truthy
    end

    it "is not reachable while locked" do
      current_session_for(user).lock!
      get edit_lock_settings_path
      expect(response).to redirect_to(lock_path)
    end
  end
end
