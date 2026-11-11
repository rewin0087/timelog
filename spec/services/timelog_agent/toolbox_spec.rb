require "rails_helper"

RSpec.describe TimelogAgent::Toolbox do
  let(:user) { create(:user, monthly_hours: 160) }
  let(:today) { Date.new(2026, 11, 11) } # a Wednesday
  let(:tools) { described_class.new(user, today:) }

  def call(name, **args) = tools.call(name, args.to_json)

  describe "log_todo" do
    it "logs today by default and reports the day's shared hours" do
      create(:time_entry, user:, log_date: today, todo: "Standup")
      result = call("log_todo", todo: "Code review")

      expect(result[:logged]).to include(date: "2026-11-11", weekday: "Wednesday", todo: "Code review")
      expect(result[:day][:todos].map { |t| t[:hours] }).to all(eq(3.81))
      expect(result[:day][:hours]).to eq(7.62)
    end

    it "logs on a given date and names leave kinds" do
      result = call("log_todo", todo: "Sick leave", date: "2026-11-03")
      expect(user.time_entries.last.log_date).to eq(Date.new(2026, 11, 3))
      expect(result[:logged][:kind]).to eq("Paid leave")
    end

    it "returns errors instead of raising" do
      expect(call("log_todo", todo: " ")).to eq(error: "The todo text is empty")
      expect(call("log_todo", todo: "x", date: "11/03/2026")).to include(:error)
      expect(call("log_todo", todo: "x", date: "2030-01-01")[:error]).to match(/more than a year/)
      expect(tools.call("log_todo", "{not json")).to eq(error: "The arguments were not valid JSON")
      expect(user.time_entries).to be_empty
    end
  end

  it "lists a range with totals and the weekdays not logged so far" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 9), todo: "Planning")
    create(:time_entry, user:, log_date: Date.new(2026, 10, 30), todo: "Elsewhere")
    result = call("list_time_entries", from: "2026-11-09", to: "2026-11-15")

    expect(result[:entries].map { |e| e[:todo] }).to eq([ "Planning" ])
    expect(result[:totals]).to include(entries: 1, days_logged: 1)
    expect(result[:weekdays_not_logged]).to eq(%w[2026-11-10 2026-11-11])
  end

  it "summarises a month" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Work")
    result = call("month_summary", month: "2026-11")
    expect(result).to include(month: "Nov 2026", status: "current", weekdays_logged: 1, target_hours: 160.0)
    expect(result[:weekdays_not_logged_so_far]).to include("2026-11-03", "2026-11-11")
    expect(result[:weekdays_still_to_log]).to eq(14) # 11-13, 16-20, 23-27, 30 Nov
    expect(result[:hours_per_weekday_to_reach_target]).to eq(((160 - 7.619) / 14).round(2))
  end

  it "lists only this user's invoices, with totals" do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 5))
    Invoice.generate_for(user, Date.new(2026, 10, 1))
    Invoice.generate_for(create(:user).tap { |u| create(:time_entry, user: u, log_date: Date.new(2026, 10, 5)) }, Date.new(2026, 10, 1))

    result = call("list_invoices")
    expect(result[:count]).to eq(1)
    expect(result[:invoices].first).to include(number: "INV-001", period: "October 2026", currency: "PHP")
  end

  it "answers unknown tools and malformed arguments with an error for the model" do
    expect(tools.call("delete_everything", "{}")).to eq(error: "Unknown tool delete_everything")
    expect(tools.call("month_summary", "[1]")).to eq(error: "The arguments must be a JSON object")
    expect(call("month_summary", month: "November")).to include(:error)
  end

  it "lists every tool's definition" do
    names = described_class.definitions.map { |d| d.dig(:function, :name) }
    expect(names).to eq(%w[get_account log_todo list_time_entries month_summary list_invoices prepare_invoice export_report])
    expect(described_class.definitions).to all(include(type: "function"))
  end

  describe "prepare_invoice" do
    before { create(:time_entry, user:, log_date: Date.new(2026, 11, 2)) }

    it "prepares the current month's invoice as a draft without saving it" do
      result = call("prepare_invoice")
      expect(result).to include(number: "INV-001", period: "November 2026", hours: 7.62)
      expect(result[:status]).to start_with("draft")
      expect(result[:note]).to match(/isn't over/)
      expect(user.invoices).to be_empty
      expect(tools.attachments).to eq([ { "kind" => "invoice_draft", "month" => "2026-11", "refresh" => false } ])
    end

    it "shows a saved invoice as it is, and drafts a refresh without changing it" do
      Invoice.generate_for(user, Date.new(2026, 11, 1), items: [ { description: "Hosting", quantity: 1, rate: 500 } ], tax_rate: 12)
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3))

      expect(call("prepare_invoice", month: "2026-11")).to include(status: "already saved; shown as it is", hours: 7.62)
      expect(tools.attachments.last).to eq("kind" => "invoice", "invoice_id" => user.invoices.sole.id)

      refreshed = call("prepare_invoice", month: "2026-11", refresh: true)
      expect(refreshed).to include(hours: 15.24, number: "INV-001", extra_items: 1)
      expect(refreshed[:status]).to start_with("draft update")
      expect(user.invoices.sole.hours).to eq(7.62)
      expect(tools.attachments.last).to eq("kind" => "invoice_draft", "month" => "2026-11", "refresh" => true)
    end

    it "explains why an invoice can't be made" do
      expect(call("prepare_invoice", month: "2026-12")[:error]).to match(/hasn't started/)
      expect(call("prepare_invoice", month: "2026-09")[:error]).to match(/Nothing is logged/)
      expect(tools.attachments).to be_empty
    end
  end

  describe "export_report" do
    it "attaches the current month's report with its totals" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      expect(call("export_report")).to include(from: "2026-11-01", to: "2026-11-30", entries: 1, hours: 7.62)
      expect(tools.attachments).to eq([ { "kind" => "report", "from" => "2026-11-01", "to" => "2026-11-30" } ])
    end

    it "takes a date range" do
      call("export_report", from: "2026-11-10", to: "2026-11-01")
      expect(tools.attachments.last).to include("from" => "2026-11-01", "to" => "2026-11-10")
    end
  end

  it "describes the account without bank details" do
    result = call("get_account")
    expect(result).to include(name: user.name, currency: "PHP", monthly_target_hours: 160.0)
    expect(result.to_json).not_to include(user.bank_account_number)
  end
end
