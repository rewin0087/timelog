require "rails_helper"

RSpec.describe "Reports" do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "November task")
    create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "October task")
  end

  it "previews the current month by default" do
    get reports_path
    expect(response.body).to include("Preview: November 2026", "November task")
    expect(response.body).not_to include("October task")
  end

  it "previews another period" do
    get reports_path(period: "previous_month")
    expect(response.body).to include("Preview: October 2026", "October task")
  end

  describe "overview charts" do
    let(:html) { Nokogiri::HTML(response.body) }

    def kpi(label) = html.css(".kpi").find { |k| k.text.include?(label) }.css(".kpi-value").text.strip

    it "summarises the selected period with per-day hours, weekdays, and top tasks" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3), todo: "November task")
      get reports_path
      expect(response.body).to include("Overview", "Hours per day", "By weekday", "Most logged tasks")
      expect(kpi("Activities logged")).to eq("2")
      expect(kpi("Weekdays logged")).to eq("2/21")
      expect(kpi("Missed weekdays")).to eq("7")
      expect(html.css("figure.chart .chart-col").size).to eq(30)
      expect(html.css(".hbars-wide .hbar-row").first.text).to include("November task", "2×")
    end

    it "groups long periods by week or month" do
      get reports_path(period: "weeks", count: 12)
      expect(response.body).to include("Hours per week")
      get reports_path(period: "custom", from: "2025-12-01", to: "2026-11-30")
      expect(response.body).to include("Hours per month")
      expect(Nokogiri::HTML(response.body).css("figure.chart .chart-col").size).to eq(12)
    end

    it "is hidden when the period has no logs" do
      get reports_path(period: "custom", from: "2026-01-01", to: "2026-01-31")
      expect(response.body).not_to include("Hours per day")
    end
  end

  describe "PDF style" do
    it "offers the design and colour pickers with the user's defaults selected" do
      user.update!(report_design: "modern", report_color: "0F766E")
      get reports_path
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("select[name=design] option[selected]")["value"]).to eq("modern")
      expect(html.at_css("input[type=color][name=color]")["value"]).to eq("#0f766e")
      expect(html.css(".pdf-swatch").size).to eq(PdfStyle::PRESETS.size)
    end

    it "keeps the style options in a Customize section, closed unless a style was picked" do
      get reports_path
      expect(Nokogiri::HTML(response.body).at_css("details.customize")["open"]).to be_nil
      get reports_path(design: "modern")
      expect(Nokogiri::HTML(response.body).at_css("details.customize")["open"]).not_to be_nil
    end

    it "exports with the picked design and colour" do
      expect(TimelogPdf).to receive(:new).with(anything, user, style: have_attributes(design: "minimal", color: "B91C1C")).and_call_original
      get export_report_path(period: "month", design: "minimal", color: "#b91c1c")
      expect(response.media_type).to eq("application/pdf")
    end
  end

  it "shows an empty state" do
    get reports_path(period: "custom", from: "2026-01-01", to: "2026-01-31")
    expect(response.body).to include("No logs in this period.")
  end

  it "downloads the PDF as an attachment" do
    get export_report_path(period: "month")
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("attachment", "timelog_2026-11-01_to_2026-11-30.pdf")
    expect(pdf_text(response.body)).to include("November task")
  end

  it "serves the PDF inline for previews" do
    get export_report_path(inline: 1)
    expect(response.headers["Content-Disposition"]).to start_with("inline")
  end
end
