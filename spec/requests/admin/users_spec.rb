require "rails_helper"

RSpec.describe "Admin users" do
  let(:user) { create(:user, name: "Jamie Rivera", bank_account_number: "0012345678", bank_swift: "BNORPHMM") }
  let(:admin) { create(:administrator, :super) }

  before { admin_sign_in(admin) }

  it "lists and searches users" do
    user
    create(:user, name: "Someone Else")
    get admin_users_path(q: "jamie")
    expect(response.body).to include("Jamie Rivera")
    expect(response.body).not_to include("Someone Else")
  end

  it "shows a user's overview charts" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Overview task")
    get admin_user_path(user)
    expect(response.body).to include("Missed weekdays", "Hours per month", "Most logged tasks", "Overview task")
  end

  describe "bank details" do
    it "are masked, with the full value only sent to super admins" do
      get edit_admin_user_path(user)
      html = Nokogiri::HTML(response.body)
      expect(html.css(".masked-dots").map(&:text)).to include("••••••5678", "BNOR••••")
      expect(html.css(".masked-value").map(&:text)).to include("0012345678")
      expect(html.css("input[name='user[bank_account_number]']").first["value"]).to be_blank
    end

    it "never reach the page for other access levels" do
      delete admin_session_path
      admin_sign_in(create(:administrator, :editor))
      get edit_admin_user_path(user)
      expect(response.body).to include("••••••5678")
      expect(response.body).not_to include("0012345678", "BNORPHMM")
    end

    it "keep stored values when left blank and change when typed" do
      patch admin_user_path(user), params: { user: { name: "Jamie R", bank_account_number: "", bank_swift: "NEWSWIFT" } }
      expect(response).to redirect_to(edit_admin_user_path(user))
      expect(user.reload).to have_attributes(name: "Jamie R", bank_account_number: "0012345678", bank_swift: "NEWSWIFT")
    end
  end

  it "creates a user who then goes through onboarding" do
    post admin_users_path, params: { user: { name: "New Person", email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
    created = User.find_by!(email_address: "new@example.com")
    expect(response).to redirect_to(admin_user_path(created))
    expect(created).not_to be_onboarded
  end

  it "changes a user's password only when given" do
    patch admin_user_path(user), params: { user: { name: "Same", password: "" } }
    expect(user.reload.authenticate_password("password123")).to be_truthy
    patch admin_user_path(user), params: { user: { password: "brandnew99", password_confirmation: "brandnew99" } }
    expect(user.reload.authenticate_password("brandnew99")).to be_truthy
  end

  it "resets the lock code and signs the user out everywhere" do
    user.sessions.create!
    patch reset_lock_admin_user_path(user)
    expect(user.reload.lock_configured?).to be(false)
    delete sign_out_everywhere_admin_user_path(user)
    expect(user.sessions.count).to eq(0)
  end

  it "deletes a user with their data" do
    create(:time_entry, user:)
    delete admin_user_path(user)
    expect(response).to redirect_to(admin_users_path)
    expect(User.exists?(user.id)).to be(false)
    expect(TimeEntry.where(user_id: user.id)).to be_empty
  end

  describe "timelogs" do
    it "lists a month and adds, edits and deletes entries" do
      get admin_user_time_entries_path(user, month: "2026-11")
      expect(response.body).to include("November 2026", "Add timelog")

      post admin_user_time_entries_path(user), params: { time_entry: { log_date: "2026-11-03", todo: "Admin added" } }
      entry = user.time_entries.last
      expect(response).to redirect_to(admin_user_time_entries_path(user, month: "2026-11"))
      expect(entry).to have_attributes(todo: "Admin added", hours: user.daily_hours_for(Date.new(2026, 11, 3)))

      patch admin_user_time_entry_path(user, entry), params: { time_entry: { todo: "Admin edited" } }
      expect(entry.reload.todo).to eq("Admin edited")

      delete admin_user_time_entry_path(user, entry)
      expect(TimeEntry.exists?(entry.id)).to be(false)
    end
  end

  describe "timelog export" do
    before do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 5), todo: "October work")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3), todo: "November work")
    end

    it "shows the export form for the month being viewed" do
      get admin_user_time_entries_path(user, month: "2026-10")
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("form.admin-export input[name=month]")["value"]).to eq("2026-10")
      expect(html.at_css("form.admin-export select[name=period] option[selected]").text).to eq("October 2026 (month shown)")
    end

    it "exports a month, a custom range, or the last N days as the user's timesheet PDF" do
      get export_admin_user_time_entries_path(user, period: "month", month: "2026-10")
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment", "jamie-rivera_timelog_2026-10-01_to_2026-10-31.pdf")
      expect(pdf_text(response.body)).to include("October work")
      expect(pdf_text(response.body)).not_to include("November work")

      get export_admin_user_time_entries_path(user, period: "custom", from: "2026-10-01", to: "2026-11-30", inline: 1)
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(pdf_text(response.body)).to include("October work", "November work")

      get export_admin_user_time_entries_path(user, period: "days", count: 30)
      expect(pdf_text(response.body)).to include("November work")
    end

    it "is allowed for view-only administrators" do
      delete admin_session_path
      admin_sign_in(create(:administrator))
      get export_admin_user_time_entries_path(user, period: "month", month: "2026-11")
      expect(response.media_type).to eq("application/pdf")
    end
  end

  describe "invoices" do
    it "generates, downloads and deletes invoices" do
      get admin_user_invoices_path(user)
      expect(response.body).to include("Generate invoice", "Billed vs logged")

      post admin_user_invoices_path(user), params: { period: "2026-10" }
      invoice = user.invoices.last
      expect(flash[:notice]).to include(invoice.code)

      get admin_user_invoice_path(user, invoice)
      expect(response.media_type).to eq("application/pdf")

      delete admin_user_invoice_path(user, invoice)
      expect(Invoice.exists?(invoice.id)).to be(false)
    end

    it "generates a custom-range invoice like the user can" do
      get admin_user_invoices_path(user)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("input#from")["value"]).to eq("2026-11-01")
      expect(html.at_css("input#to")["value"]).to eq("2026-11-13")
      expect(html.at_css("input#due_date")["value"]).to eq("2026-12-05")

      post admin_user_invoices_path(user), params: { from: "2026-11-02", to: "2026-11-06", due_date: "2026-11-20" }
      invoice = user.invoices.last
      expect(invoice).to have_attributes(period_start: Date.new(2026, 11, 2), period_end: Date.new(2026, 11, 6), due_date: Date.new(2026, 11, 20))
      expect(flash[:notice]).to include("2–6 November 2026")
    end

    it "generates an invoice with extra items and tax for the user" do
      user.update!(tax_rate: 8)
      get admin_user_invoices_path(user)
      expect(Nokogiri::HTML(response.body).at_css("input#tax_rate")["value"]).to eq("8")
      post admin_user_invoices_path(user), params: { period: "2026-10", tax_rate: "0", items: { "0" => { description: "Laptop allowance", quantity: "1", rate: "3000" } } }
      invoice = user.invoices.last
      expect(invoice).to have_attributes(tax_rate: 0, amount: 163_000)
      get admin_user_invoices_path(user)
      expect(response.body).to include("+ 1 extra item", "PHP 163,000.00")
    end

    it "saves a user's default tax rate" do
      patch admin_user_path(user), params: { user: { tax_rate: "12.5" } }
      expect(user.reload.tax_rate).to eq(12.5)
    end

    it "explains invalid custom ranges" do
      post admin_user_invoices_path(user), params: { from: "2026-10-28", to: "2026-11-03", due_date: "2026-11-20" }
      expect(flash[:alert]).to include("same month")
      post admin_user_invoices_path(user), params: { from: "bad", to: "2026-11-03", due_date: "2026-11-20" }
      expect(flash[:alert]).to eq("Pick a valid month, or a valid date range and due date.")
    end
  end
end
