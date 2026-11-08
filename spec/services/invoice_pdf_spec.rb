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

  it "lists extra items and applies the tax rate to the total" do
    invoice = Invoice.generate_for(user, Date.new(2026, 10, 1), tax_rate: 10,
                                   items: [ { description: "Equipment allowance", quantity: 1, rate: 5000 }, { description: "Travel", quantity: 2, rate: 1000 } ])
    text = pdf_text(InvoicePdf.new(invoice).render)
    expect(text).to include("Consultancy Service", "P160,000", "Equipment allowance", "P5,000", "Travel", "P2,000")
    expect(text).to include("Subtotal:", "P167,000", "Tax (10%):", "P16,700", "Total:", "P183,700", "PHP 183,700")
  end

  it "shows zero tax by default" do
    text = pdf_text(InvoicePdf.new(Invoice.generate_for(user, Date.new(2026, 10, 1))).render)
    expect(text).to include("Tax (0%):", "PHP 0.00")
  end

  it "shows the period for a part-month invoice" do
    invoice = Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
    expect(pdf_text(InvoicePdf.new(invoice).render)).to include("1–15 October 2026")
  end
end
