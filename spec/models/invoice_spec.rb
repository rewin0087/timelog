require "rails_helper"

RSpec.describe Invoice do
  let(:user) { create(:user, :fixed_rate, hourly_rate: 1000, invoice_due_day: 5) }

  describe ".generate_for" do
    it "bills a whole month at 160 hours, dated the last day, due on the due day" do
      invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
      expect(invoice).to have_attributes(
        number: 1, period: Date.new(2026, 10, 1), period_start: Date.new(2026, 10, 1), period_end: Date.new(2026, 10, 31),
        invoice_date: Date.new(2026, 10, 31), due_date: Date.new(2026, 11, 5), hours: 160, rate: 1000, currency: "PHP"
      )
      expect(invoice.amount).to eq(160_000)
      expect(invoice).to be_full_month
    end

    it "bills 160 hours regardless of what was logged" do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1))
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1)).hours).to eq(160)
    end

    it "refreshes the same month instead of creating another invoice" do
      first = Invoice.generate_for(user, Date.new(2026, 10, 1))
      user.update!(hourly_rate: 1200)
      second = Invoice.generate_for(user, Date.new(2026, 10, 15))
      expect(second.id).to eq(first.id)
      expect(second.reload.rate).to eq(1200)
      expect(user.invoices.count).to eq(1)
    end

    it "numbers invoices per user" do
      Invoice.generate_for(user, Date.new(2026, 9, 1))
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1)).number).to eq(2)
      expect(Invoice.generate_for(create(:user, :fixed_rate), Date.new(2026, 10, 1)).number).to eq(1)
    end
  end

  describe ".generate_for_range" do
    it "prorates 160 hours by the weekdays in the range" do
      invoice = Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
      expect(invoice.hours).to eq(80) # 11 of 22 weekdays
      expect(invoice.invoice_date).to eq(Date.new(2026, 10, 15))
      expect(invoice).not_to be_full_month
    end

    it "uses the given due date" do
      invoice = Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15), due_date: Date.new(2026, 10, 20))
      expect(invoice.due_date).to eq(Date.new(2026, 10, 20))
    end

    it "rejects ranges that span two months" do
      expect { Invoice.generate_for_range(user, Date.new(2026, 10, 20), Date.new(2026, 11, 5)) }
        .to raise_error(ActiveRecord::RecordInvalid, /same month/)
    end

    it "rejects a start date after the end date" do
      expect { Invoice.generate_for_range(user, Date.new(2026, 10, 20), Date.new(2026, 10, 5)) }
        .to raise_error(ActiveRecord::RecordInvalid, /on or before/)
    end

    it "rejects overlapping periods" do
      Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
      expect { Invoice.generate_for_range(user, Date.new(2026, 10, 10), Date.new(2026, 10, 31)) }
        .to raise_error(ActiveRecord::RecordInvalid, /INV-001 already covers 1–15 October 2026/)
    end

    it "allows other users to invoice the same period" do
      Invoice.generate_for(user, Date.new(2026, 10, 1))
      expect { Invoice.generate_for(create(:user, :fixed_rate), Date.new(2026, 10, 1)) }.not_to raise_error
    end

    it "rejects a due date before the invoice date" do
      expect { Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15), due_date: Date.new(2026, 10, 14)) }
        .to raise_error(ActiveRecord::RecordInvalid, /can't be before the invoice date/)
    end
  end

  describe ".hours_for" do
    it "returns the target for a full month and a share for part of it" do
      expect(Invoice.hours_for(user, Date.new(2026, 11, 1), Date.new(2026, 11, 30))).to eq(160)
      expect(Invoice.hours_for(user, Date.new(2026, 11, 2), Date.new(2026, 11, 2))).to eq(BigDecimal("7.62"))
    end

    it "uses the user's own monthly target" do
      user.update!(monthly_hours: 120)
      expect(Invoice.hours_for(user, Date.new(2026, 11, 1), Date.new(2026, 11, 30))).to eq(120)
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1))).to have_attributes(hours: 120, amount: 120_000)
    end
  end

  context "with no monthly target" do
    before { user.update!(hours_mode: "daily") }

    it "bills the hours actually logged: 8h per logged weekday, weekends 0h" do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1))
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1))
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2))
      create(:time_entry, user:, log_date: Date.new(2026, 10, 3)) # Saturday
      invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
      expect(invoice.hours).to eq(16)
      expect(invoice.amount).to eq(16_000)
    end

    it "has no monthly cap" do
      (Date.new(2026, 10, 1)..Date.new(2026, 10, 31)).reject(&:on_weekend?).each { |d| create(:time_entry, user:, log_date: d) }
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1)).hours).to eq(176) # 22 weekdays x 8h
    end

    it "refuses an invoice with nothing logged" do
      expect { Invoice.generate_for(user, Date.new(2026, 10, 1)) }
        .to raise_error(ActiveRecord::RecordInvalid, /Nothing is logged between 1 Oct and 31 Oct 2026/)
    end
  end

  describe ".default_period" do
    it "is the previous month until the month's last day" do
      expect(Invoice.default_period(Date.new(2026, 11, 13))).to eq(Date.new(2026, 10, 1))
      expect(Invoice.default_period(Date.new(2026, 11, 30))).to eq(Date.new(2026, 11, 1))
    end
  end

  describe "labels" do
    it "formats the code, period label, and filename" do
      full = Invoice.generate_for(user, Date.new(2026, 9, 1))
      part = Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 15))
      expect(full.code).to eq("INV-001")
      expect(full.period_label).to eq("September 2026")
      expect(part.period_label).to eq("1–15 October 2026")
      expect(full.filename).to eq("invoice-#{user.name.parameterize}-2026-09.pdf")
      expect(part.filename).to eq("invoice-#{user.name.parameterize}-2026-10-01-to-2026-10-15.pdf")
    end
  end

  describe "leave and unpaid days" do
    let(:user) { create(:user, :invoice_ready, hourly_rate: 1000) }

    it "bills paid leave like work and unpaid days as nothing, from time logs" do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1), todo: "Paid vacation leave")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "Absent")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 5), todo: "Unpaid sick leave")
      invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
      expect(invoice).to have_attributes(hours_basis: "logged", hours: user.daily_hours_for(Date.new(2026, 10, 1)).round(2))
    end

    it "ignores leave and unpaid days entirely at the fixed monthly rate" do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "Absent")
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1), hours_basis: "target").hours).to eq(160)
    end

    it "bills only logged billable hours with no monthly target" do
      user.update!(hours_mode: "daily")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1), todo: "Sick leave")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "Absent")
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1)).hours).to eq(8)
    end

    it "refuses an invoice for a range that is only unpaid days with no monthly target" do
      user.update!(hours_mode: "daily")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "Absent")
      expect { Invoice.generate_for_range(user, Date.new(2026, 10, 2), Date.new(2026, 10, 2)) }.to raise_error(ActiveRecord::RecordInvalid, /no hours to bill/)
    end
  end

  describe "hours basis" do
    let(:user) { create(:user, hourly_rate: 1000) } # new accounts bill from time logs

    before do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1), todo: "Work")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 2), todo: "Work")
    end

    it "defaults to the billable hours from time logs" do
      expect(user.invoice_hours_basis).to eq("logged")
      invoice = Invoice.generate_for(user, Date.new(2026, 10, 1))
      expect(invoice).to have_attributes(hours_basis: "logged", hours: (2 * user.daily_hours_for(Date.new(2026, 10, 1))).round(2))
      expect(invoice).not_to be_fixed_rate
    end

    it "skips time logs at the fixed monthly rate, when asked or by the user's default" do
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1), hours_basis: "target")).to have_attributes(hours_basis: "target", hours: 160)
      user.update!(invoice_hours_basis: "target")
      expect(Invoice.generate_for(user, Date.new(2026, 9, 1)).hours).to eq(160)
      user.invoices.destroy_all
      expect(Invoice.generate_for_range(user, Date.new(2026, 10, 1), Date.new(2026, 10, 2), hours_basis: "logged").hours_basis).to eq("logged")
    end

    it "always bills logged hours without a monthly target" do
      user.update!(hours_mode: "daily", invoice_hours_basis: "target")
      expect(Invoice.hours_basis_for(user, "target")).to eq("logged")
      expect(Invoice.generate_for(user, Date.new(2026, 10, 1), hours_basis: "target")).to have_attributes(hours_basis: "logged", hours: 16)
    end

    it "ignores an unknown basis" do
      expect(Invoice.hours_basis_for(user, "bogus")).to eq("logged")
      user.update!(invoice_hours_basis: "target")
      expect(Invoice.hours_basis_for(user, "bogus")).to eq("target")
    end

    it "refuses an invoice from time logs when nothing billable was logged" do
      expect { Invoice.generate_for(user, Date.new(2026, 9, 1)) }.to raise_error(ActiveRecord::RecordInvalid, /no hours to bill/)
    end
  end
end
