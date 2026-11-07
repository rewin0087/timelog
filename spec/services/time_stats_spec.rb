require "rails_helper"

RSpec.describe TimeStats do
  let(:user) { create(:user) }
  let(:stats) { described_class.new(user, today: Date.new(2026, 11, 13)) }

  def log(date, todo = "Work") = create(:time_entry, user:, log_date: date, todo:)

  describe ".holiday_kind" do
    it "classifies holidays from the todo text, case-insensitively" do
      expect(described_class.holiday_kind("PUBLIC HOLIDAY")).to eq(:public)
      expect(described_class.holiday_kind("Regular holiday - Bonifacio Day")).to eq(:public)
      expect(described_class.holiday_kind("Special non-working holiday")).to eq(:non_working)
      expect(described_class.holiday_kind("Non working day")).to eq(:non_working)
      expect(described_class.holiday_kind("Company holiday")).to eq(:holiday)
      expect(described_class.holiday_kind("Fix bug")).to be_nil
    end

    it "labels each kind" do
      expect(described_class.holiday_label(:non_working)).to eq("Non-working holiday")
    end
  end

  describe "#months" do
    it "summarises hours, entries, days, weekdays, and holidays per month" do
      log(Date.new(2026, 10, 1)); log(Date.new(2026, 10, 1)); log(Date.new(2026, 10, 2), "Public holiday")
      log(Date.new(2026, 10, 3)) # Saturday
      oct = stats.months(Date.new(2026, 10, 1), Date.new(2026, 10, 1)).first

      expect(oct).to have_attributes(month: Date.new(2026, 10, 1), weekdays: 22, entries: 4, days_logged: 3, weekdays_logged: 2)
      expect(oct.hours).to be_within(0.001).of(2 * 7.2727)
      expect(oct.holidays).to eq(public: 1, non_working: 0, holiday: 0)
      expect(oct.holiday_days).to eq(1)
      expect(oct.label).to eq("Oct 2026")
      expect(oct).not_to be_complete
      expect(oct.remaining).to be_within(0.01).of(160 - 14.5454)
    end

    it "counts a holiday day once even with several entries" do
      log(Date.new(2026, 11, 2), "Public holiday"); log(Date.new(2026, 11, 2), "Public holiday again")
      expect(stats.current_month.holidays[:public]).to eq(1)
    end

    it "marks a fully logged month complete" do
      (Date.new(2026, 10, 1)..Date.new(2026, 10, 31)).reject(&:on_weekend?).each { |d| log(d) }
      oct = stats.months(Date.new(2026, 10, 1), Date.new(2026, 10, 1)).first
      expect(oct).to be_complete
      expect(oct.percent).to eq(100)
      expect(oct.remaining).to be_within(0.01).of(0)
    end

    it "uses the user's own target" do
      user.update!(monthly_hours: 120)
      expect(stats.current_month.target).to eq(120)
    end

    it "uses weekdays x 8h as the most a month can hold with no target" do
      user.update!(hours_mode: "daily")
      log(Date.new(2026, 10, 1))
      oct = stats.months(Date.new(2026, 10, 1), Date.new(2026, 10, 1)).first
      expect(oct.target).to eq(176)
      expect(oct.hours).to eq(8)
      expect(stats.expected_to_date).to eq(80) # 10 weekdays so far in November
    end

    it "returns empty months too, oldest first" do
      expect(stats.previous_months(3).map(&:month)).to eq([ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1) ])
      expect(stats.previous_months(3).map(&:hours)).to all(eq(0))
    end

    it "ignores other users" do
      create(:time_entry, log_date: Date.new(2026, 11, 2))
      expect(stats.current_month.entries).to eq(0)
    end
  end

  describe "current month helpers" do
    it "lists every day with hours, entries, and holiday kind" do
      log(Date.new(2026, 11, 2)); log(Date.new(2026, 11, 3), "Non-working holiday")
      days = stats.current_month_days
      expect(days.size).to eq(30)
      expect(days[1]).to have_attributes(entries: 1, holiday: nil)
      expect(days[2].holiday).to eq(:non_working)
      expect(days[0]).to be_weekend
    end

    it "computes expected hours to date, missed weekdays, and weekdays left" do
      log(Date.new(2026, 11, 2)); log(Date.new(2026, 11, 3))
      expect(stats.expected_to_date).to be_within(0.001).of(10 * 7.619) # 2..6, 9..13
      expect(stats.missed_weekdays).to eq([ 4, 5, 6, 9, 10, 11, 12 ].map { |d| Date.new(2026, 11, d) })
      expect(stats.weekdays_left).to eq(12) # Fri 13th, 16-20, 23-27, 30th
    end
  end

  describe "#activity" do
    it "covers whole weeks, with counts up to today and nil after" do
      log(Date.new(2026, 11, 12)); log(Date.new(2026, 11, 12))
      cells = stats.activity(2)
      expect(cells.size).to eq(14)
      expect(cells.first.first).to eq(Date.new(2026, 11, 2))
      expect(cells.to_h[Date.new(2026, 11, 12)]).to eq(2)
      expect(cells.to_h[Date.new(2026, 11, 14)]).to be_nil
    end
  end

  it "counts entries by weekday" do
    log(Date.new(2026, 11, 2)); log(Date.new(2026, 11, 9)); log(Date.new(2026, 11, 7))
    expect(stats.entries_by_weekday).to include([ "Mon", 2 ], [ "Sat", 1 ], [ "Sun", 0 ])
    expect(stats.entries_by_weekday.map(&:first)).to eq(%w[Mon Tue Wed Thu Fri Sat Sun])
  end

  it "ranks the most logged tasks, ignoring case and spacing" do
    log(Date.new(2026, 11, 2), "Standup"); log(Date.new(2026, 11, 3), " standup "); log(Date.new(2026, 11, 4), "Review")
    expect(stats.top_tasks).to eq([ [ "Standup", 2 ], [ "Review", 1 ] ])
  end

  it "totals all entries" do
    log(Date.new(2026, 10, 1)); log(Date.new(2026, 11, 2)); log(Date.new(2026, 11, 2))
    expect(stats.totals).to include(entries: 3, days: 2, since: Date.new(2026, 10, 1))
  end

  it "compares billed and logged hours per invoiced month" do
    user.update!(address: "x", hourly_rate: 100, bank_account_name: "x", bank_account_number: "1", bank_name: "x", bank_swift: "x")
    Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
    Invoice.generate_for_range(user, Date.new(2026, 10, 16), Date.new(2026, 10, 31))
    log(Date.new(2026, 10, 1))
    oct = stats.invoice_months(2).first
    expect(oct).to include(month: Date.new(2026, 10, 1), billed_hours: 160, amount: 16_000, invoices: 2, currency: "PHP")
    expect(oct[:logged_hours]).to be_within(0.001).of(7.2727)
    expect(stats.invoice_months(2).last).to include(invoices: 0, billed_hours: 0)
  end
end
