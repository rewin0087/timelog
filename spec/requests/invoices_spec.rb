require "rails_helper"

RSpec.describe "Invoices" do
  let(:user) { create(:user, :invoice_ready, hourly_rate: 1000) }

  before { sign_in(user) }

  describe "GET /invoices" do
    it "defaults to the last finished month and prefills the custom range" do
      get invoices_path
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("select#period option[selected]")["value"]).to eq("2026-10")
      expect(html.css("select#period option").map(&:text)).to include("October 2026", "Custom dates…")
      expect(html.css("select#period option").size).to eq(13)
      expect(html.at_css("input#tax_rate")["value"]).to eq("0")
      expect(html.at_css("input#from")["value"]).to eq("2026-11-01")
      expect(html.at_css("input#to")["value"]).to eq("2026-11-13")
      expect(html.at_css("input#due_date")["value"]).to eq("2026-12-05")
    end

    it "prefills the custom range after the last part-month invoice" do
      Invoice.generate_for_range(user, Date.new(2026, 11, 1), Date.new(2026, 11, 6))
      get invoices_path
      expect(Nokogiri::HTML(response.body).at_css("input#from")["value"]).to eq("2026-11-07")
    end

    it "sends users with incomplete invoice details back to onboarding" do
      user.update!(bank_swift: nil, address: nil)
      get invoices_path
      expect(response).to redirect_to(onboarding_path)
    end

    it "lists invoices with masked amounts and the charts" do
      Invoice.generate_for(user, Date.new(2026, 10, 1))
      get invoices_path
      expect(response.body).to include("INV-001", "October 2026", "Billed vs logged hours", "Amount billed", "Invoice timeline")
      expect(response.body).to include("PHP ••••••", "PHP 160,000.00")
    end

    it "hides the charts with no invoices" do
      get invoices_path
      expect(response.body).to include("No invoices yet.")
      expect(response.body).not_to include("Billed vs logged hours")
    end

    it "does not show the amount scale on the amount chart" do
      Invoice.generate_for(user, Date.new(2026, 10, 1))
      get invoices_path
      chart = Nokogiri::HTML(response.body).css("figure.chart-noticks")
      expect(chart).to be_present
      expect(chart.css(".chart-grid i")).to be_empty
    end
  end

  describe "POST /invoices" do
    it "generates a whole-month invoice" do
      expect { post invoices_path, params: { period: "2026-10" } }.to change(user.invoices, :count).by(1)
      expect(response).to redirect_to(invoices_path)
      expect(flash[:notice]).to eq("Invoice INV-001 for October 2026 generated.")
    end

    it "generates a custom-range invoice" do
      post invoices_path, params: { from: "2026-11-02", to: "2026-11-06", due_date: "2026-11-20" }
      invoice = user.invoices.last
      expect(invoice).to have_attributes(period_start: Date.new(2026, 11, 2), period_end: Date.new(2026, 11, 6), due_date: Date.new(2026, 11, 20))
      expect(flash[:notice]).to include("2–6 November 2026")
    end

    it "shows validation errors" do
      post invoices_path, params: { from: "2026-10-20", to: "2026-11-05", due_date: "2026-11-20" }
      expect(flash[:alert]).to include("same month")
    end

    it "bills logged hours with no monthly target" do
      user.update!(hours_mode: "daily")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1))
      post invoices_path, params: { period: "2026-10" }
      expect(user.invoices.last.hours).to eq(8)
      post invoices_path, params: { period: "2026-09" }
      expect(flash[:alert]).to include("Nothing is logged between 1 Sep and 30 Sep 2026")
    end

    it "handles malformed dates" do
      post invoices_path, params: { period: "nonsense" }
      expect(flash[:alert]).to eq("Pick a valid month, or a valid date range and due date.")
    end

    it "requires complete invoice details" do
      user.update!(hourly_rate: nil)
      expect { post invoices_path, params: { period: "2026-10" } }.not_to change(Invoice, :count)
      expect(response).to redirect_to(onboarding_path)
    end
  end

  describe "extra items and tax" do
    it "generates a month invoice with extra items and a tax override" do
      post invoices_path, params: { period: "2026-10", tax_rate: "12",
                                    items: { "0" => { description: "Equipment allowance", quantity: "1", rate: "5000" },
                                             "1" => { description: "Internet reimbursement", quantity: "2", rate: "1500" },
                                             "2" => { description: "", quantity: "", rate: "" } } }
      invoice = user.invoices.last
      expect(flash[:notice]).to eq("Invoice INV-001 for October 2026 generated with 2 extra items and 12% tax.")
      expect(invoice.items.map(&:description)).to eq([ "Equipment allowance", "Internet reimbursement" ])
      expect(invoice).to have_attributes(service_amount: 160_000, items_amount: 8_000, subtotal: 168_000, tax_amount: 20_160, amount: 188_160)
    end

    it "goes by the selected period even when hidden custom dates are submitted" do
      post invoices_path, params: { period: "2026-10", from: "2026-11-01", to: "2026-11-13", due_date: "2026-12-05" }
      expect(user.invoices.last).to have_attributes(period_start: Date.new(2026, 10, 1), period_end: Date.new(2026, 10, 31))
    end

    it "uses the profile tax rate by default and for custom dates" do
      user.update!(tax_rate: 5)
      post invoices_path, params: { period: "custom", from: "2026-11-02", to: "2026-11-06", due_date: "2026-11-20", tax_rate: "" }
      expect(user.invoices.last.tax_rate).to eq(5)
    end

    it "explains invalid extra items and keeps nothing" do
      post invoices_path, params: { period: "2026-10", items: { "0" => { description: "", quantity: "1", rate: "100" } } }
      expect(flash[:alert]).to include("Extra item 1: description can't be blank")
      expect(user.invoices).to be_empty
      post invoices_path, params: { period: "2026-10", tax_rate: "150" }
      expect(flash[:alert]).to include("Tax rate must be less than or equal to 100")
    end

    it "replaces the extra items when the same period is generated again" do
      post invoices_path, params: { period: "2026-10", items: { "0" => { description: "Old", quantity: "1", rate: "10" } } }
      post invoices_path, params: { period: "2026-10", items: { "0" => { description: "New", quantity: "1", rate: "20" } } }
      expect(user.invoices.count).to eq(1)
      expect(user.invoices.last.items.map(&:description)).to eq([ "New" ])
    end
  end

  describe "PDF style and preview" do
    it "stores the picked design and colour on the invoice, and uses them for its PDF" do
      post invoices_path, params: { period: "2026-10", design: "modern", color: "#4f46e5" }
      invoice = user.invoices.last
      expect(invoice.style).to have_attributes(design: "modern", color: "4F46E5")
      expect(InvoicePdf).to receive(:new).with(have_attributes(id: invoice.id)).and_call_original
      get invoice_path(invoice)
    end

    it "falls back to the user's invoice defaults" do
      user.update!(invoice_design: "minimal", invoice_color: "0F766E")
      post invoices_path, params: { period: "2026-10" }
      expect(user.invoices.last).to have_attributes(design: "minimal", color: "0F766E")
    end

    it "previews the draft PDF without saving anything" do
      get preview_invoices_path(period: "2026-10", design: "modern", color: "#0f766e", tax_rate: "10", inline: 1,
                                items: { "0" => { description: "Preview allowance", quantity: "1", rate: "500" } })
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(pdf_text(response.body)).to include("INV-001", "Preview allowance", "Tax (10%):")
      expect(user.invoices.count).to eq(0)
      expect(InvoiceItem.count).to eq(0)
    end

    it "previews a refresh of an existing invoice with its number" do
      Invoice.generate_for(user, Date.new(2026, 10, 1))
      get preview_invoices_path(period: "2026-10")
      expect(response.media_type).to eq("application/pdf")
      expect(pdf_text(response.body)).to include("INV-001")
    end

    it "explains what is wrong instead of a PDF" do
      Invoice.generate_for(user, Date.new(2026, 11, 1))
      get preview_invoices_path(period: "custom", from: "2026-11-02", to: "2026-11-06", due_date: "2026-11-20")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Can't preview this invoice yet", "INV-001 already covers November 2026")
      get preview_invoices_path(period: "custom", from: "nope")
      expect(response.body).to include("Pick a valid month")
    end
  end

  describe "GET /invoices/:id" do
    let(:invoice) { Invoice.generate_for(user, Date.new(2026, 10, 1)) }

    it "downloads the PDF" do
      get invoice_path(invoice)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment", invoice.filename)
    end

    it "serves it inline for previews" do
      get invoice_path(invoice, inline: 1)
      expect(response.headers["Content-Disposition"]).to start_with("inline")
    end

    it "cannot open another user's invoice" do
      other = Invoice.generate_for(create(:user, :invoice_ready), Date.new(2026, 10, 1))
      get invoice_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end
