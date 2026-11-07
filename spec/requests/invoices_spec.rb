require "rails_helper"

RSpec.describe "Invoices" do
  let(:user) { create(:user, :invoice_ready, hourly_rate: 1000) }

  before { sign_in(user) }

  describe "GET /invoices" do
    it "defaults to the last finished month and prefills the custom range" do
      get invoices_path
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("select#period option[selected]")["value"]).to eq("2026-10")
      expect(html.css("select#period option").size).to eq(12)
      expect(html.at_css("input#from")["value"]).to eq("2026-11-01")
      expect(html.at_css("input#to")["value"]).to eq("2026-11-13")
      expect(html.at_css("input#due_date")["value"]).to eq("2026-12-05")
    end

    it "prefills the custom range after the last part-month invoice" do
      Invoice.generate_for_range(user, Date.new(2026, 11, 1), Date.new(2026, 11, 6))
      get invoices_path
      expect(Nokogiri::HTML(response.body).at_css("input#from")["value"]).to eq("2026-11-07")
    end

    it "warns when the profile is incomplete" do
      user.update!(bank_swift: nil, address: nil)
      get invoices_path
      expect(response.body).to include("Complete your", "Address and SWIFT")
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

    it "requires a complete profile" do
      user.update!(hourly_rate: nil)
      expect { post invoices_path, params: { period: "2026-10" } }.not_to change(Invoice, :count)
      expect(response).to redirect_to(edit_profile_path)
      expect(flash[:alert]).to include("Hourly rate")
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
