require "rails_helper"

RSpec.describe "Inspirations" do
  before { sign_in(create(:user)) }

  it "renders today's verse and trivia without a layout" do
    create(:daily_inspiration, day: Date.current)
    get inspiration_path
    expect(response.body).to start_with("<turbo-frame id=\"inspiration\">")
    expect(response.body).to include("Whatever you do, work heartily.", "Colossians 3:23", "data-controller=\"trivia\"")
    expect(response.body).not_to include("inspiration-compact")
  end

  it "renders the compact variant for the lock screen" do
    get inspiration_path(compact: 1)
    expect(response.body).to include("inspiration-compact")
  end

  it "uses the built-in fallback when the AI is not configured" do
    expect { get inspiration_path }.to change(DailyInspiration, :count).by(1)
    expect(DailyInspiration.last).to be_fallback
  end
end
