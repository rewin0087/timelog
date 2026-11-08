require "rails_helper"

RSpec.describe "Registrations" do
  let(:params) { { user: { name: "Jamie Rivera", email_address: "jamie@example.com", password: "password123", password_confirmation: "password123" } } }

  it "shows the sign-up form" do
    get new_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Create account")
  end

  it "creates the account, signs in, and starts onboarding" do
    expect { post registration_path, params: }.to change(User, :count).by(1).and change(Session, :count).by(1)
    expect(response).to redirect_to(onboarding_path)
    expect(flash[:notice]).to start_with("Welcome!")
    follow_redirect!
    expect(response.body).to include("Your invoice details")
  end

  it "shows errors for invalid input" do
    post registration_path, params: { user: params[:user].merge(password_confirmation: "different") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password confirmation doesn&#39;t match")
  end

  it "rejects a taken email" do
    create(:user, email_address: "jamie@example.com")
    expect { post registration_path, params: }.not_to change(User, :count)
    expect(response.body).to include("Email address has already been taken")
  end

  it "redirects signed-in users away" do
    sign_in(create(:user))
    get new_registration_path
    expect(response).to redirect_to(root_path)
  end
end
