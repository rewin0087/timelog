require "rails_helper"

RSpec.describe ReportRange do
  let(:today) { Date.new(2026, 11, 13) }

  def range(params) = described_class.new(ActionController::Parameters.new(params), today:)

  it "defaults to the current month" do
    r = range({})
    expect([ r.from, r.to, r.label ]).to eq([ Date.new(2026, 11, 1), Date.new(2026, 11, 30), "November 2026" ])
  end

  it "uses a specific month" do
    r = range(period: "month", month: "2026-02")
    expect([ r.from, r.to, r.label ]).to eq([ Date.new(2026, 2, 1), Date.new(2026, 2, 28), "February 2026" ])
  end

  it "falls back to the current month for an invalid month or period" do
    expect(range(month: "bad").from).to eq(Date.new(2026, 11, 1))
    expect(range(period: "decade").from).to eq(Date.new(2026, 11, 1))
  end

  it "covers the previous month" do
    r = range(period: "previous_month")
    expect([ r.from, r.to, r.label ]).to eq([ Date.new(2026, 10, 1), Date.new(2026, 10, 31), "October 2026" ])
  end

  it "covers the last N days, ending today" do
    r = range(period: "days", count: "7")
    expect([ r.from, r.to, r.label ]).to eq([ Date.new(2026, 11, 7), today, "Last 7 days" ])
    expect(range(period: "days", count: "1").label).to eq("Last 1 day")
  end

  it "covers the last N weeks" do
    r = range(period: "weeks", count: "2")
    expect([ r.from, r.label ]).to eq([ Date.new(2026, 10, 31), "Last 2 weeks" ])
  end

  it "clamps the count to 1..366" do
    expect(range(period: "days", count: "0").from).to eq(today)
    expect(range(period: "days", count: "9999").from).to eq(today - 365)
  end

  it "uses a custom range and swaps reversed dates" do
    r = range(period: "custom", from: "2026-11-10", to: "2026-11-01")
    expect([ r.from, r.to ]).to eq([ Date.new(2026, 11, 1), Date.new(2026, 11, 10) ])
    expect(r.label).to eq("01 Nov 2026 – 10 Nov 2026")
  end

  it "fills in missing custom dates" do
    r = range(period: "custom", from: "nope")
    expect([ r.from, r.to ]).to eq([ Date.new(2026, 11, 1), today ])
  end

  it "builds the filename" do
    expect(range({}).filename).to eq("timelog_2026-11-01_to_2026-11-30.pdf")
  end

  it "returns only the user's entries in range, oldest first" do
    user = create(:user)
    b = create(:time_entry, user:, log_date: Date.new(2026, 11, 5))
    a = create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    create(:time_entry, user:, log_date: Date.new(2026, 10, 30))
    create(:time_entry, log_date: Date.new(2026, 11, 3))
    expect(range({}).entries(user)).to eq([ a, b ])
  end
end
