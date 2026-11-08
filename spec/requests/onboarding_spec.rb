require "rails_helper"

RSpec.describe "Onboarding" do
  let(:user) { create(:user, :new_signup) }
  let(:details) do
    { name: "Jamie Rivera", address: "1 Main St", bill_to_name: "Acme Ltd", bill_to_address: "1 Client Way\nLondon", hourly_rate: "1000", currency: "PHP", invoice_due_day: "5",
      bank_account_name: "Jamie Rivera", bank_account_number: "0012", bank_name: "BDO", bank_swift: "BNORPHMM" }
  end

  before { sign_in(user) }

  it "sends every page to onboarding until it is done" do
    get time_entries_path
    expect(response).to redirect_to(onboarding_path)
    post heartbeat_lock_path, as: :json
    expect(response).to have_http_status(:locked)
  end

  it "starts with the invoice details step and hides the sidebar" do
    get onboarding_path
    expect(response.body).to include("Your invoice details", "Continue")
    expect(response.body).not_to include("aside class=\"sidebar\"")
  end

  it "requires every invoice field" do
    patch onboarding_path(step: "invoice"), params: { user: details.merge(address: "", bank_swift: "") }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Address can&#39;t be blank", "Bank swift can&#39;t be blank")
  end

  it "does not open the lock step before the invoice details are done" do
    get onboarding_path(step: "lock")
    expect(response.body).to include("Your invoice details")
  end

  it "saves invoice details, then the lock code, and continues to the page that was blocked" do
    get invoices_path
    patch onboarding_path(step: "invoice"), params: { user: details }
    expect(response).to redirect_to(onboarding_path(step: "lock"))
    expect(user.reload).to be_invoice_details_complete

    get onboarding_path
    expect(response.body).to include("Set up your lock screen", "Finish setup")

    patch onboarding_path(step: "lock"), params: { user: { lock_pin: "", lock_pin_confirmation: "" } }
    expect(response.body).to include("Lock code can&#39;t be blank")
    patch onboarding_path(step: "lock"), params: { user: { lock_pin: "1234", lock_pin_confirmation: "1234" } }
    expect(response.body).to include("too easy to guess")

    patch onboarding_path(step: "lock"), params: { user: { lock_pin: "2580", lock_pin_confirmation: "2580", auto_lock_minutes: 15 } }
    expect(response).to redirect_to(invoices_url)
    expect(flash[:notice]).to start_with("You're all set")
    expect(user.reload).to have_attributes(onboarded?: true, auto_lock_minutes: 15)
  end

  it "only asks for what is missing" do
    user.update!(lock_pin: "2580")
    patch onboarding_path(step: "invoice"), params: { user: details }
    expect(response).to redirect_to(root_url)
  end

  it "can't be revisited once done" do
    user.update!(details.merge(lock_pin: "2580"))
    get onboarding_path
    expect(response).to redirect_to(root_url)
  end
end
