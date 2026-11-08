require "rails_helper"

RSpec.describe DayKind do
  def key(todo) = described_class.for(todo)&.key

  it "recognises paid leave as billable" do
    [ "Paid holiday", "On vacation", "On Vacation in Cebu", "Sick leave", "Paid sick leave", "Paid vacation leave", "vacation leave" ].each do |todo|
      expect(key(todo)).to eq(:paid_leave), todo
      expect(described_class.billable?(todo)).to be(true), todo
    end
  end

  it "recognises unpaid days as not billable, before any paid wording" do
    [ "Absent", "absent (family matter)", "Unpaid sick leave", "Unpaid vacation leave", "Unpaid vacation", "Unpaid holiday", "unpaid leave" ].each do |todo|
      expect(key(todo)).to eq(:unpaid), todo
      expect(described_class.billable?(todo)).to be(false), todo
    end
  end

  it "keeps the holiday kinds and normal work billable" do
    expect(key("Regular holiday - Bonifacio Day")).to eq(:public)
    expect(key("Special non-working holiday")).to eq(:non_working)
    expect(key("Company holiday")).to eq(:holiday)
    expect(key("Fix bug")).to be_nil
    expect(described_class.billable?("Fix bug")).to be(true)
    expect(key("Absentee report review")).to be_nil
  end

  it "finds days where every todo is unpaid" do
    rows = [ [ Date.new(2026, 11, 2), "Absent" ], [ Date.new(2026, 11, 3), "Absent" ], [ Date.new(2026, 11, 3), "Fix bug" ] ]
    expect(described_class.unpaid_dates(rows)).to eq([ Date.new(2026, 11, 2) ])
  end
end
