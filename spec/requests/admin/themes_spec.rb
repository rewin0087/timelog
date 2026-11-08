require "rails_helper"

RSpec.describe "Admin skin" do
  before { admin_sign_in(create(:administrator)) }

  def body_theme = Nokogiri::HTML(response.body).at_css("body")["data-theme"]

  it "defaults to dark and toggles to light and back" do
    get admin_root_path
    expect(body_theme).to eq("midnight")
    expect(response.body).to include("Light", "Dark")

    patch admin_theme_path, params: { theme: "light" }, as: :json
    expect(response).to have_http_status(:no_content)
    get admin_root_path
    expect(body_theme).to eq("violet")

    patch admin_theme_path, params: { theme: "dark" }
    expect(response).to redirect_to(admin_root_path)
    get admin_users_path
    expect(body_theme).to eq("midnight")
  end

  it "ignores unknown skins and leaves the app user's skin alone" do
    patch admin_theme_path, params: { theme: "neon" }
    get admin_root_path
    expect(body_theme).to eq("midnight")
    expect(session[:theme]).to be_nil
  end
end
