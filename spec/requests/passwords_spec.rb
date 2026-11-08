require "rails_helper"

RSpec.describe "Password (on the profile)" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  def change(current: "password123", password: "newpassword1", confirmation: password)
    patch password_path, params: { current_password: current, user: { password:, password_confirmation: confirmation } }
  end

  it "shows the password form on the profile" do
    get edit_profile_path
    expect(response.body).to include("Current password", "New password (min 8 characters)", "Update password")
  end

  it "changes the password and signs out other devices only" do
    other = user.sessions.create!
    change
    expect(response).to redirect_to(edit_profile_path(anchor: "password"))
    expect(flash[:notice]).to start_with("Password updated")
    expect(user.reload.authenticate_password("newpassword1")).to be_truthy
    expect(Session.exists?(other.id)).to be(false)
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "requires the current password" do
    change(current: "wrong-one")
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Current password is incorrect", "Invoice details")
    expect(user.reload.authenticate_password("password123")).to be_truthy
  end

  it "rejects a blank, short, or mismatched new password" do
    change(password: "")
    expect(response.body).to include("Password can&#39;t be blank")
    change(password: "short")
    expect(response.body).to include("Password is too short")
    change(confirmation: "different1")
    expect(response.body).to include("Password confirmation doesn&#39;t match")
    expect(user.reload.authenticate_password("password123")).to be_truthy
  end
end
