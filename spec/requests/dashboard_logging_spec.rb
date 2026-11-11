require "rails_helper"

RSpec.describe "Dashboard logging choice" do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    create(:daily_inspiration)
  end

  def hero = Nokogiri::HTML(response.body).at_css(".logging-hero")

  context "with the assistant set up" do
    around { |example| with_fuelix_key { example.run } }

    it "shows both as tabs by default, todo first" do
      get root_path
      expect(hero.css("[role=tab]").map(&:text).map(&:strip)).to eq([ "Today's todo", "✦ Assistant" ])
      expect(hero.at_css("#hero-panel-todo")["hidden"]).to be_nil
      expect(hero.at_css("#hero-panel-assistant")["hidden"]).not_to be_nil
    end

    it "saves the choice and shows only what was picked" do
      patch dashboard_logging_path, params: { mode: "assistant" }
      expect(response).to redirect_to(root_path)
      expect(user.reload.dashboard_logging).to eq("assistant")

      get root_path
      expect(hero.at_css("#hero-panel-todo")).to be_nil
      expect(hero.at_css("#hero-panel-assistant")).to be_present
      expect(hero.css("[role=tab]")).to be_empty
      expect(hero.at_css(".hero-option.active").text).to eq("Assistant only")

      patch dashboard_logging_path, params: { mode: "todo" }
      get root_path
      expect(hero.at_css("#hero-panel-assistant")).to be_nil
      expect(hero.at_css("#hero-panel-todo")).to be_present
    end

    it "rejects unknown choices" do
      patch dashboard_logging_path, params: { mode: "everything" }
      expect(flash[:alert]).to be_present
      expect(user.reload.dashboard_logging).to eq("both")
    end
  end

  it "falls back to today's todo, with no options, when the assistant isn't set up" do
    user.update!(dashboard_logging: "assistant")
    get root_path
    expect(hero.at_css("#hero-panel-todo")).to be_present
    expect(hero.at_css("#hero-panel-assistant, .hero-settings")).to be_nil
  end
end
