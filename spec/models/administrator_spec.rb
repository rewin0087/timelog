require "rails_helper"

RSpec.describe Administrator do
  it "maps access levels to permissions" do
    expectations = {
      "view" => { view: true, create: false, edit: false, destroy: false, reveal: false, manage_admins: false },
      "create" => { create: true, edit: false, destroy: false },
      "edit" => { create: false, edit: true, destroy: false },
      "create_edit" => { create: true, edit: true, destroy: false, manage_admins: false },
      "all" => { create: true, edit: true, destroy: true, reveal: true, manage_admins: true }
    }
    expectations.each do |level, perms|
      admin = build(:administrator, access_level: level)
      expect(admin.access_level).to eq(level)
      perms.each { |action, allowed| expect(admin.can?(action)).to be(allowed), "#{level} #{action}" }
    end
  end

  it "requires a 10+ character password and a unique email" do
    expect(build(:administrator, password: "short")).not_to be_valid
    create(:administrator, email_address: "a@example.com")
    expect(build(:administrator, email_address: "A@example.com ")).not_to be_valid
  end

  it "keeps at least one super admin" do
    only = create(:administrator, :super)
    expect(only.destroy).to be(false)
    expect(only.update(access_level: "view")).to be(false)
    create(:administrator, :super)
    expect(only.reload.update(access_level: "view")).to be(true)
  end
end
