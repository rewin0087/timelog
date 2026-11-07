require "rails_helper"

RSpec.describe "Themes" do
  before { sign_in(create(:user)) }

  it "saves the skin in the session and applies it" do
    patch theme_path, params: { theme: "midnight" }, headers: { "HTTP_REFERER" => "http://www.example.com/invoices" }
    expect(response).to redirect_to("http://www.example.com/invoices")
    get root_path
    expect(response.body).to include('data-theme="midnight"')
  end

  it "answers JSON requests with no content" do
    patch theme_path, params: { theme: "ocean" }, as: :json
    expect(response).to have_http_status(:no_content)
  end

  it "falls back to the default for unknown skins" do
    patch theme_path, params: { theme: "not-a-skin" }
    get root_path
    expect(response.body).to include('data-theme="violet"')
  end
end
