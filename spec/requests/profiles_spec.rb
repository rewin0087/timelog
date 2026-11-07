require "rails_helper"

RSpec.describe "Profile" do
  let(:user) { create(:user, auto_lock_minutes: 15) }

  before { sign_in(user) }

  it "shows the profile and lock summary" do
    get edit_profile_path
    expect(response.body).to include(user.email_address, "Locks automatically after <strong>15 minutes</strong>")
  end

  it "says when auto-lock is off" do
    user.update!(auto_lock_minutes: 0)
    get edit_profile_path
    expect(response.body).to include("Auto-lock is <strong>off</strong>")
  end

  it "saves invoice details" do
    patch profile_path, params: { user: { name: "New Name", address: "Addr", hourly_rate: "1500", currency: "USD",
                                          bank_account_name: "A", bank_account_number: "1", bank_name: "B", bank_swift: "S", invoice_due_day: "10" } }
    expect(response).to redirect_to(root_path)
    expect(user.reload).to have_attributes(name: "New Name", hourly_rate: 1500, currency: "USD", invoice_due_day: 10)
  end

  it "saves a custom monthly target and recalculates logs" do
    entry = create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    patch profile_path, params: { user: { hours_mode: "monthly", monthly_hours: "168" } }
    expect(flash[:notice]).to eq("Profile saved. Hours on your logs were recalculated.")
    expect(user.reload.monthly_hours).to eq(168)
    expect(entry.reload.hours).to eq(8)
  end

  it "switches to no monthly target" do
    patch profile_path, params: { user: { hours_mode: "daily" } }
    expect(user.reload).to be_no_target
    get root_path
    expect(response.body).to include("No monthly target: each logged weekday counts <strong>8h</strong>")
  end

  it "does not mention recalculation when hours settings are unchanged" do
    patch profile_path, params: { user: { name: "Same Hours" } }
    expect(flash[:notice]).to eq("Profile saved.")
  end

  it "rejects an invalid target" do
    patch profile_path, params: { user: { monthly_hours: "0" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Monthly target hours must be greater than 0")
  end

  it "does not change email or password through the profile" do
    patch profile_path, params: { user: { email_address: "hacker@example.com", password: "newpassword" } }
    expect(user.reload.email_address).not_to eq("hacker@example.com")
    expect(user.authenticate_password("password123")).to be_truthy
  end

  it "shows errors" do
    patch profile_path, params: { user: { hourly_rate: "-1" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Hourly rate must be greater than 0")
  end
end
