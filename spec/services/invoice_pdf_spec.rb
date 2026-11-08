require "rails_helper"

RSpec.describe InvoicePdf do
  let(:user) { create(:user, :invoice_ready, name: "Jamie Rivera", hourly_rate: 1000, bank_name: "BDO") }

  it "renders the invoice with header, bill-to, line item, totals, and bank details" do
    invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
    text = pdf_text(InvoicePdf.new(invoice).render)
    expect(text).to include("JAMIE RIVERA", "INVOICE", "INV-001", "Bill to:", "Acme Ltd", "1 Client Way", "London")
    expect(text).to include("Consultancy Service", "160", "Bank Details:", "BDO", "Payment Method: Bank Transfer")
    expect(text).to include("October 31, 2026", "November 5, 2026")
  end

  it "uses the invoice item from the profile" do
    user.update!(invoice_item: "Software Development")
    text = pdf_text(InvoicePdf.new(Invoice.generate_for(user, Date.new(2026, 10, 1))).render)
    expect(text).to include("Software Development")
    expect(text).not_to include("Consultancy Service")
  end

  it "shows the period for a part-month invoice" do
    invoice = Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
    expect(pdf_text(InvoicePdf.new(invoice).render)).to include("1–15 October 2026")
  end
end
