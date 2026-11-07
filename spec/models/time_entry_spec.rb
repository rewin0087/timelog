require "rails_helper"

RSpec.describe TimeEntry do
  let(:user) { create(:user) }

  it "requires a date and a todo" do
    entry = build(:time_entry, user:, log_date: nil, todo: "")
    expect(entry).not_to be_valid
    expect(entry.errors.attribute_names).to include(:log_date, :todo)
  end

  describe ".weekdays_in_month" do
    it "counts Monday to Friday" do
      expect(TimeEntry.weekdays_in_month(Date.new(2026, 11, 1))).to eq(21)
      expect(TimeEntry.weekdays_in_month(Date.new(2026, 10, 15))).to eq(22)
      expect(TimeEntry.weekdays_in_month(Date.new(2026, 2, 1))).to eq(20)
    end
  end

  describe "hour balancing" do
    let(:monday) { Date.new(2026, 11, 9) }

    it "gives a single entry the whole day" do
      entry = create(:time_entry, user:, log_date: monday)
      expect(entry.reload.hours).to eq(BigDecimal("7.6190"))
    end

    it "splits the day equally between that day's entries" do
      a = create(:time_entry, user:, log_date: monday)
      b = create(:time_entry, user:, log_date: monday)
      expect([ a.reload.hours, b.reload.hours ]).to all(eq(BigDecimal("3.8095")))
    end

    it "rebalances both days when an entry moves" do
      a = create(:time_entry, user:, log_date: monday)
      b = create(:time_entry, user:, log_date: monday)
      b.update!(log_date: monday + 1)
      expect(a.reload.hours).to eq(BigDecimal("7.6190"))
      expect(b.reload.hours).to eq(BigDecimal("7.6190"))
    end

    it "rebalances the day when an entry is deleted" do
      a = create(:time_entry, user:, log_date: monday)
      create(:time_entry, user:, log_date: monday).destroy
      expect(a.reload.hours).to eq(BigDecimal("7.6190"))
    end

    it "gives weekend entries 0 hours" do
      expect(create(:time_entry, user:, log_date: Date.new(2026, 11, 14)).reload.hours).to eq(0)
    end

    it "uses the user's own monthly target" do
      user.update!(monthly_hours: 168)
      expect(create(:time_entry, user:, log_date: monday).reload.hours).to eq(8)
    end

    it "counts 8h per logged weekday with no monthly target" do
      user.update!(hours_mode: "daily")
      a = create(:time_entry, user:, log_date: monday)
      b = create(:time_entry, user:, log_date: monday)
      expect([ a.reload.hours, b.reload.hours ]).to all(eq(4))
      expect(create(:time_entry, user:, log_date: Date.new(2026, 11, 14)).reload.hours).to eq(0)
    end

    it "does not touch other users' entries on the same day" do
      other = create(:time_entry, log_date: monday)
      create(:time_entry, user:, log_date: monday)
      expect(other.reload.hours).to eq(BigDecimal("7.6190"))
    end
  end

  describe "scopes" do
    it "filters by date range and sorts chronologically" do
      late = create(:time_entry, user:, log_date: Date.new(2026, 11, 10))
      early = create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      create(:time_entry, user:, log_date: Date.new(2026, 10, 30))
      expect(user.time_entries.between(Date.new(2026, 11, 1), Date.new(2026, 11, 30)).chronological).to eq([ early, late ])
    end
  end
end
