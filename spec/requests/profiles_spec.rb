require "rails_helper"

RSpec.describe "Profile" do
  let(:user) { create(:user, auto_lock_minutes: 15) }

  before { sign_in(user) }

  it "requires every invoice field" do
    patch profile_path, params: { section: "profile", user: { address: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Address can&#39;t be blank")
    patch profile_path, params: { section: "invoice", user: { bank_name: "", bill_to_address: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Bank name can&#39;t be blank", "Bill to address can&#39;t be blank")
    expect(user.reload).to have_attributes(address: be_present, bank_name: be_present)
  end

  it "defaults the invoice item and lets it be changed but not cleared" do
    get edit_profile_path
    expect(response.body).to include('value="Consultancy Service"')
    patch profile_path, params: { section: "invoice", user: { invoice_item: "Software Development" } }
    expect(user.reload.invoice_item).to eq("Software Development")
    patch profile_path, params: { section: "invoice", user: { invoice_item: "" } }
    expect(response.body).to include("Invoice item can&#39;t be blank")
  end

  it "shows the profile and lock summary" do
    get edit_profile_path
    expect(response.body).to include(user.email_address, "Locks automatically after <strong>15 minutes</strong>")
  end

  it "says when auto-lock is off" do
    user.update!(auto_lock_minutes: 0)
    get edit_profile_path
    expect(response.body).to include("Auto-lock is <strong>off</strong>")
  end

  it "shows profile and invoice details as separate forms" do
    get edit_profile_path
    html = Nokogiri::HTML(response.body)
    profile = html.at_css("#profile form")
    invoice = html.at_css("#invoice-details form")
    profile_fields = profile.css("input, textarea").map { |i| i["name"] }
    invoice_fields = invoice.css("input, textarea").map { |i| i["name"] }
    expect(profile_fields).to include("user[name]", "user[address]", "user[hours_mode]")
    expect(profile_fields).not_to include("user[bank_name]")
    expect(invoice_fields).to include("user[bill_to_name]", "user[hourly_rate]", "user[bank_name]")
    expect(invoice_fields).not_to include("user[name]")
  end

  it "saves the profile form" do
    patch profile_path, params: { section: "profile", user: { name: "New Name", address: "Addr" } }
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("Profile saved.")
    expect(user.reload).to have_attributes(name: "New Name", address: "Addr")
  end

  it "saves the invoice details form" do
    patch profile_path, params: { section: "invoice", user: { hourly_rate: "1500", currency: "USD", bank_account_name: "A",
                                                              bank_account_number: "1", bank_name: "B", bank_swift: "S", invoice_due_day: "10" } }
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("Invoice details saved.")
    expect(user.reload).to have_attributes(hourly_rate: 1500, currency: "USD", invoice_due_day: 10, bank_name: "B")
  end

  it "only saves the fields of the submitted form" do
    patch profile_path, params: { section: "profile", user: { name: "Kept", bank_name: "Ignored" } }
    patch profile_path, params: { section: "invoice", user: { bank_name: "Saved", name: "Ignored" } }
    expect(user.reload).to have_attributes(name: "Kept", bank_name: "Saved")
  end

  it "shows errors only on the form that was submitted" do
    patch profile_path, params: { section: "invoice", user: { bank_name: "" } }
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("#invoice-details .flash.alert").text).to include("Bank name can't be blank")
    expect(html.at_css("#profile .flash.alert")).to be_nil
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
    patch profile_path, params: { section: "invoice", user: { hourly_rate: "-1" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Hourly rate must be greater than 0")
  end
end
