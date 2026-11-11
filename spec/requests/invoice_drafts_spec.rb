require "rails_helper"

RSpec.describe "Invoice drafts" do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
  end

  it "previews a month's invoice as often as you like without saving it" do
    2.times { get invoice_draft_path("2026-11", inline: 1) }

    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("inline", "draft-invoice-")
    expect(user.invoices).to be_empty
  end

  it "saves the invoice on download, then sends its PDF, never twice" do
    post "/invoice_drafts/2026-11"
    invoice = user.invoices.sole
    expect(response).to redirect_to(invoice_path(invoice))
    follow_redirect!
    expect(response.headers["Content-Disposition"]).to include("attachment")

    post "/invoice_drafts/2026-11"
    expect(user.invoices.count).to eq(1)
    expect(response).to redirect_to(invoice_path(invoice))
  end

  it "previews a refresh of a saved invoice without changing it, and saves it on download keeping its extras" do
    Invoice.generate_for(user, Date.new(2026, 11, 1), items: [ { description: "Hosting", quantity: 1, rate: 500 } ], tax_rate: 12)
    create(:time_entry, user:, log_date: Date.new(2026, 11, 3))

    get invoice_draft_path("2026-11", refresh: 1)
    expect(user.invoices.sole.hours).to eq(7.62)

    post "/invoice_drafts/2026-11", params: { refresh: 1 }
    expect(user.invoices.sole).to have_attributes(hours: 15.24, tax_rate: 12, number: 1)
    expect(user.invoices.sole.items.map(&:description)).to eq([ "Hosting" ])
  end

  it "explains why a month can't be invoiced" do
    get invoice_draft_path("2026-09")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nothing is logged")

    post "/invoice_drafts/2026-09"
    expect(response).to redirect_to(invoices_path)
    expect(user.invoices).to be_empty
  end

  it "only touches the signed-in user's invoices" do
    other = create(:user)
    create(:time_entry, user: other, log_date: Date.new(2026, 11, 2))
    post "/invoice_drafts/2026-11"
    expect(other.invoices).to be_empty
  end
end
