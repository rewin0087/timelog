require "rails_helper"

RSpec.describe "Admin access" do
  let(:user) { create(:user) }

  it "requires an administrator sign-in, separate from app users" do
    get admin_root_path
    expect(response).to redirect_to(new_admin_session_path)
    sign_in(user)
    get admin_users_path
    expect(response).to redirect_to(new_admin_session_path)
    post admin_session_path, params: { email_address: user.email_address, password: "password123" }
    expect(response).to redirect_to(new_admin_session_path)
    expect(flash[:alert]).to eq("Try another email address or password.")
  end

  it "signs in and out" do
    admin = create(:administrator)
    admin_sign_in(admin)
    expect(response).to redirect_to(admin_root_path)
    expect(admin.reload.last_signed_in_at).to be_present
    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    delete admin_session_path
    get admin_root_path
    expect(response).to redirect_to(new_admin_session_path)
  end

  it "shows the dashboard with global stats" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Global task")
    admin_sign_in(create(:administrator))
    get admin_root_path
    html = Nokogiri::HTML(response.body)
    expect(response.body).to include("Hours logged", "Active users", "Top users", "Latest activity", "Global task", user.name)
    expect(html.css(".admin-kpi").map { |k| k.css(".kpi-label").text }).to include("Users", "Active this month", "Hours this month")
  end

  describe "permissions" do
    it "lets a viewer browse everything but change nothing" do
      admin_sign_in(create(:administrator))
      [ admin_users_path, admin_user_path(user), admin_user_time_entries_path(user), admin_user_invoices_path(user), edit_admin_user_path(user) ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
      end
      expect(response.body).to include("read only")
      expect(response.body).not_to include("Delete user", "Save details")

      patch admin_user_path(user), params: { user: { name: "Hacked" } }
      expect(response).to redirect_to(admin_root_path)
      expect(flash[:alert]).to include("View only")
      post admin_user_time_entries_path(user), params: { time_entry: { log_date: "2026-11-02", todo: "x" } }
      delete admin_user_path(user)
      get admin_administrators_path
      expect(user.reload.name).not_to eq("Hacked")
      expect(user.time_entries.count).to eq(0)
      expect(response).to redirect_to(admin_root_path)
    end

    it "lets a creator create but not edit or delete" do
      admin_sign_in(create(:administrator, :creator))
      post admin_users_path, params: { user: { name: "New Person", email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
      expect(User.find_by(email_address: "new@example.com")).to be_present
      patch admin_user_path(user), params: { user: { name: "Edited" } }
      expect(user.reload.name).not_to eq("Edited")
    end

    it "lets an editor edit but not create or delete" do
      admin_sign_in(create(:administrator, :editor))
      patch admin_user_path(user), params: { user: { name: "Edited" } }
      expect(user.reload.name).to eq("Edited")
      get new_admin_user_path
      expect(response).to redirect_to(admin_root_path)
      delete admin_user_path(user)
      expect(User.exists?(user.id)).to be(true)
    end
  end
end
