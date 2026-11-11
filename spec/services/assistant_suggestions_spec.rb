require "rails_helper"

# The suite runs on Friday 13 November 2026.
RSpec.describe AssistantSuggestions do
  let(:user) { create(:user) }
  let(:labels) { described_class.new(user).to_a.map(&:label) }

  it "puts logging today and the missed days first" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
    expect(labels.first).to eq("Log what I worked on today")
    expect(labels.second).to eq("Fill in 8 missed days (Tue 3 Nov, Wed 4 Nov, Thu 5 Nov +5)")
    expect(described_class.new(user).to_a.second.message).to include("Tue 3 Nov", "Thu 12 Nov")
  end

  it "flags last month when it has logs but no invoice" do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 5))
    expect(labels).to include("October isn't invoiced yet")

    Invoice.generate_for(user, Date.new(2026, 10, 1))
    expect(described_class.new(user).to_a.map(&:label)).not_to include("October isn't invoiced yet")
  end

  it "falls back to general questions once everything is up to date" do
    (Date.new(2026, 11, 2)..Date.new(2026, 11, 13)).reject(&:on_weekend?).each { |d| create(:time_entry, user:, log_date: d) }
    expect(labels).to eq([ "How many hours are left this month?", "Summarise my week" ])
  end

  context "at the end of the month", at: Time.zone.local(2026, 11, 28, 10) do
    it "offers this month's invoice and report first" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      expect(labels.first(2)).to eq([ "Preview November invoice", "November time log report" ])
      expect(described_class.new(user).to_a.first.message).to eq("Prepare my invoice for November 2026 so I can preview it.")
    end

    it "offers to show the invoice once it exists" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      Invoice.generate_for(user, Date.new(2026, 11, 1))
      expect(labels.first).to eq("Show INV-001 (November)")
    end
  end

  context "early in the next month", at: Time.zone.local(2026, 12, 2, 10) do
    it "offers last month's invoice and report" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      expect(labels).to include("Preview November invoice", "November time log report")
      expect(labels).not_to include("November isn't invoiced yet")
    end
  end
end
