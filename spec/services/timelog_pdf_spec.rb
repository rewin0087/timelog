require "rails_helper"

RSpec.describe TimelogPdf do
  let(:user) { create(:user, name: "Jamie Rivera") }

  def render(params) = TimelogPdf.new(ReportRange.new(ActionController::Parameters.new(params)), user).render

  it "renders a month timesheet with the user's entries and total" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Fix the login bug")
    create(:time_entry, user:, log_date: Date.new(2026, 11, 3), todo: "Write release notes")
    create(:time_entry, log_date: Date.new(2026, 11, 3), todo: "Someone else's task")
    pdf = render({})

    expect(pdf).to start_with("%PDF")
    text = pdf_text(pdf)
    expect(text).to include("TIMESHEET - NOVEMBER 2026", "JAMIE RIVERA", "COVERED PERIOD: NOVEMBER 1 - 30 2026")
    expect(text).to include("Fix the login bug", "Write release notes", "Monday, November 2, 2026", "7.62", "TOTAL", "15.24")
    expect(text).not_to include("Someone else's task")
  end

  it "describes ranges across months and years" do
    expect(pdf_text(render(period: "custom", from: "2026-10-25", to: "2026-11-10"))).to include("TIMESHEET", "OCTOBER 25 - NOVEMBER 10 2026")
    expect(pdf_text(render(period: "custom", from: "2025-12-20", to: "2026-01-05"))).to include("DECEMBER 20 2025 - JANUARY 5 2026")
  end
end
