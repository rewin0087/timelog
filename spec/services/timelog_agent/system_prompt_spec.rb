require "rails_helper"

RSpec.describe TimelogAgent::SystemPrompt do
  let(:today) { Date.new(2026, 11, 13) }

  it "includes the user, today's date, their hours rule, leave kinds and the suggestions format" do
    user = create(:user, monthly_hours: 160)
    prompt = described_class.new(user, today:).to_s

    expect(prompt).to include(user.name, "Friday, 13 November 2026 (2026-11-13)")
    expect(prompt).to include("fixed monthly target of 160.0h", "7.62h per weekday")
    expect(prompt).to include("  - Unpaid / absent: logged, but 0 hours and never billed", "Paid examples: Paid holiday")
    expect(prompt).to include('<suggestions>["...", "..."]</suggestions>')
  end

  it "explains the no-target rule" do
    prompt = described_class.new(create(:user, hours_mode: "daily"), today:).to_s
    expect(prompt).to include("no monthly target: each logged weekday counts 8h")
  end

  it "asks for invoice and report suggestions at the end of a month" do
    user = create(:user)
    expect(described_class.new(user, today: Date.new(2026, 11, 29)).to_s).to include("It's the end of November")
    expect(described_class.new(user, today: Date.new(2026, 12, 1)).to_s).to include("November has just ended")
    expect(described_class.new(user, today:).to_s).not_to include("has just ended", "It's the end of")
  end
end
