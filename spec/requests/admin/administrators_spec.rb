require "rails_helper"

RSpec.describe "Admin administrators" do
  let(:admin) { create(:administrator, :super, name: "Root") }

  before { admin_sign_in(admin) }

  it "lists administrators with their access" do
    create(:administrator, :editor, name: "Edna Editor")
    get admin_administrators_path
    expect(response.body).to include("Root", "Edna Editor", "View + edit", "All access (super admin)")
  end

  it "creates an administrator with an access level" do
    post admin_administrators_path, params: { administrator: { name: "Vera", email_address: "vera@example.com", password: "long-password", password_confirmation: "long-password", access_level: "create_edit" } }
    expect(response).to redirect_to(admin_administrators_path)
    expect(Administrator.find_by!(email_address: "vera@example.com")).to have_attributes(can_create: true, can_edit: true, super_admin: false)
  end

  it "changes access and keeps the password when left blank" do
    other = create(:administrator)
    patch admin_administrator_path(other), params: { administrator: { access_level: "all", password: "" } }
    expect(other.reload).to be_super_admin
    expect(other.authenticate_password("admin-password")).to be_truthy
  end

  it "won't delete yourself or the last super admin" do
    delete admin_administrator_path(admin)
    expect(flash[:alert]).to eq("You can't delete your own account.")
    patch admin_administrator_path(admin), params: { administrator: { access_level: "view" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(admin.reload).to be_super_admin
  end

  it "removes another administrator" do
    other = create(:administrator)
    delete admin_administrator_path(other)
    expect(Administrator.exists?(other.id)).to be(false)
  end
end
