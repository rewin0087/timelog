require "rails_helper"

RSpec.describe User do
  describe "validations" do
    it "is valid from the factory" do
      expect(build(:user)).to be_valid
    end

    it "requires a name and email address" do
      user = build(:user, name: "", email_address: "")
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
      expect(user.errors[:email_address]).to be_present
    end

    it "normalizes the email address and keeps it unique" do
      create(:user, email_address: "  Jamie@Example.COM ")
      expect(User.last.email_address).to eq("jamie@example.com")
      expect(build(:user, email_address: "jamie@example.com")).not_to be_valid
    end

    it "requires passwords of at least 8 characters" do
      expect(build(:user, password: "short")).not_to be_valid
    end

    it "requires a positive hourly rate when one is given" do
      expect(build(:user, hourly_rate: 0)).not_to be_valid
      expect(build(:user, hourly_rate: nil)).to be_valid
    end

    it "requires an invoice due day between 1 and 31" do
      expect(build(:user, invoice_due_day: 0)).not_to be_valid
      expect(build(:user, invoice_due_day: 32)).not_to be_valid
      expect(build(:user, invoice_due_day: 31)).to be_valid
    end

    it "only allows the listed auto-lock periods" do
      expect(build(:user, auto_lock_minutes: 7)).not_to be_valid
      User::AUTO_LOCK_OPTIONS.each_value { |m| expect(build(:user, auto_lock_minutes: m)).to be_valid }
    end
  end

  describe "lock code" do
    it "accepts 4 to 8 digit codes" do
      expect(build(:user, lock_pin: "2580")).to be_valid
      expect(build(:user, lock_pin: "25804713")).to be_valid
    end

    it "rejects codes that are too short, too long, or not digits" do
      %w[123 123456789 12a4].each do |pin|
        user = build(:user, lock_pin: pin)
        expect(user).not_to be_valid, "expected #{pin} to be rejected"
        expect(user.errors[:lock_pin]).to include("must be 4 to 8 digits")
      end
    end

    it "rejects trivial codes" do
      %w[0000 1234 9876 4321 1111].each do |pin|
        user = build(:user, lock_pin: pin)
        user.valid?
        expect(user.errors[:lock_pin]).to include("is too easy to guess"), "expected #{pin} to be rejected"
      end
    end

    it "requires the confirmation to match when given" do
      user = build(:user, lock_pin: "2580", lock_pin_confirmation: "2581")
      expect(user).not_to be_valid
    end

    it "stores a digest and authenticates with it" do
      user = create(:user, lock_pin: "2580")
      expect(user.lock_configured?).to be(true)
      expect(user.authenticate_lock_pin("2580")).to eq(user)
      expect(user.authenticate_lock_pin("0000")).to be(false)
    end

    it "is not configured without a code" do
      expect(create(:user, :without_lock).lock_configured?).to be(false)
    end
  end

  describe "working hours" do
    it "defaults to a fixed 160h monthly target" do
      user = build(:user)
      expect(user.hours_mode).to eq("monthly")
      expect(user.monthly_target).to eq(160)
      expect(user).to be_fixed_target
    end

    it "uses a custom monthly target when set" do
      expect(build(:user, monthly_hours: 120).monthly_target).to eq(120)
    end

    it "has no monthly target in daily mode" do
      user = build(:user, hours_mode: "daily", monthly_hours: 120)
      expect(user.monthly_target).to be_nil
      expect(user).to be_no_target
    end

    it "validates the mode and target" do
      expect(build(:user, hours_mode: "weekly")).not_to be_valid
      expect(build(:user, monthly_hours: 0)).not_to be_valid
      expect(build(:user, monthly_hours: 745)).not_to be_valid
      expect(build(:user, monthly_hours: 172.5)).to be_valid
    end

    describe "#daily_hours_for" do
      it "spreads the monthly target over the month's weekdays" do
        user = build(:user)
        expect(user.daily_hours_for(Date.new(2026, 2, 2))).to eq(8)
        expect(user.daily_hours_for(Date.new(2026, 11, 2))).to eq(BigDecimal("7.6190"))
        expect(user.daily_hours_for(Date.new(2026, 10, 1))).to eq(BigDecimal("7.2727"))
        expect(build(:user, monthly_hours: 168).daily_hours_for(Date.new(2026, 11, 2))).to eq(8)
      end

      it "is a flat 8h with no monthly target" do
        expect(build(:user, hours_mode: "daily").daily_hours_for(Date.new(2026, 10, 1))).to eq(8)
      end

      it "gives weekends no hours in either mode" do
        expect(build(:user).daily_hours_for(Date.new(2026, 11, 14))).to eq(0)
        expect(build(:user, hours_mode: "daily").daily_hours_for(Date.new(2026, 11, 15))).to eq(0)
      end
    end

    it "caps a month at the target, or weekdays x 8h with no target" do
      expect(build(:user).month_capacity(Date.new(2026, 10, 1))).to eq(160)
      expect(build(:user, hours_mode: "daily").month_capacity(Date.new(2026, 10, 1))).to eq(176)
    end

    it "recalculates existing logs when the settings change" do
      user = create(:user)
      entry = create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      expect(entry.reload.hours).to eq(BigDecimal("7.6190"))

      user.update!(monthly_hours: 168)
      expect(entry.reload.hours).to eq(8)

      user.update!(hours_mode: "daily", monthly_hours: nil)
      expect(entry.reload.hours).to eq(8)

      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      user.update!(hours_mode: "monthly")
      expect(entry.reload.hours).to eq(BigDecimal("3.8095"))
    end

    it "keeps stored invoice hours when the settings change" do
      user = create(:user, :invoice_ready)
      invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
      user.update!(monthly_hours: 100)
      expect(invoice.reload.hours).to eq(160)
    end
  end

  describe "#auto_lock?" do
    it "is off when set to Never" do
      expect(build(:user, auto_lock_minutes: 0).auto_lock?).to be(false)
      expect(build(:user, auto_lock_minutes: 5).auto_lock?).to be(true)
    end
  end

  describe "invoice details" do
    it "are optional at sign-up but required in the invoice_details context" do
      user = build(:user, :new_signup)
      expect(user).to be_valid
      expect(user.valid?(:invoice_details)).to be(false)
      expect(user.errors.attribute_names).to contain_exactly(:address, :bill_to_name, :bill_to_address, :hourly_rate, :bank_account_name, :bank_account_number, :bank_name, :bank_swift)
      expect(build(:user).valid?(:invoice_details)).to be(true)
    end
  end

  describe "#onboarded?" do
    it "needs both invoice details and a lock code" do
      expect(build(:user)).to be_onboarded
      expect(build(:user, :without_lock)).not_to be_onboarded
      expect(build(:user, :without_invoice_details)).not_to be_onboarded
    end
  end

  describe "#missing_invoice_fields" do
    it "lists every blank invoice field" do
      expect(build(:user, :without_invoice_details).missing_invoice_fields).to eq([ "Address", "Bill to name", "Bill to address", "Hourly rate", "Bank account name", "Bank account number", "Bank name", "SWIFT" ])
    end

    it "is empty when the profile is complete" do
      expect(build(:user, :invoice_ready).missing_invoice_fields).to be_empty
    end
  end

  describe "#invoice_due_date_after" do
    it "uses the due day of the following month" do
      expect(build(:user, invoice_due_day: 5).invoice_due_date_after(Date.new(2026, 10, 31))).to eq(Date.new(2026, 11, 5))
    end

    it "caps the due day at the end of a short month" do
      expect(build(:user, invoice_due_day: 31).invoice_due_date_after(Date.new(2026, 10, 31))).to eq(Date.new(2026, 11, 30))
      expect(build(:user, invoice_due_day: 30).invoice_due_date_after(Date.new(2027, 1, 31))).to eq(Date.new(2027, 2, 28))
    end
  end

  it "deletes its sessions, entries, and invoices with it" do
    user = create(:user, :invoice_ready)
    create(:session, user:)
    create(:time_entry, user:)
    Invoice.generate_for(user, Date.new(2026, 10, 1))
    expect { user.destroy }.to change(Session, :count).by(-1).and change(TimeEntry, :count).by(-1).and change(Invoice, :count).by(-1)
  end
end
