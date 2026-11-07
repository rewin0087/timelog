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
