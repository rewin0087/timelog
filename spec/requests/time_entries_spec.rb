require "rails_helper"

RSpec.describe "Time entries" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /time_entries" do
    it "lists only the user's entries, newest first, with the charts" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Older task")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 10), todo: "Newer task")
      create(:time_entry, log_date: Date.new(2026, 11, 10), todo: "Not mine")
      get time_entries_path
      expect(response.body).to include("Older task", "Newer task", "Hours per month", "Activities per month", "Most logged tasks")
      expect(response.body).not_to include("Not mine")
      expect(response.body.index("Newer task")).to be < response.body.index("Older task")
    end

    it "shows this month's and all-time figures in the summary tiles" do
      create(:time_entry, user:, log_date: Date.new(2026, 10, 1))
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      get time_entries_path
      page = Nokogiri::HTML(response.body)
      activities = page.css(".stat-split").find { |t| t.text.include?("Activities logged") }
      expect(activities.css(".stat-value").text.strip).to eq("1")
      expect(activities.css(".split-value").text.strip).to eq("2")
    end

    it "shows an empty state" do
      get time_entries_path
      expect(response.body).to include("Nothing logged yet.")
    end
  end

  describe "pagination" do
    before do
      stub_const("TimeEntriesController::PER_PAGE", 2)
      5.times { |i| create(:time_entry, user:, log_date: Date.new(2026, 11, 2) + i, todo: "Entry #{i + 1}") }
    end

    def todos = Nokogiri::HTML(response.body).css("table.rtable td.cell-main").map(&:text)

    it "shows the newest page first with charts and links to older pages" do
      get time_entries_path
      expect(todos).to eq([ "Entry 5", "Entry 4" ])
      expect(response.body).to include("Showing 1–2 of 5 entries", "page 1 of 3", "Hours per month")
      expect(response.body).to include(%(href="/time_entries?page=2"))
    end

    it "shows older entries on later pages, without the charts" do
      get time_entries_path(page: 3)
      expect(todos).to eq([ "Entry 1" ])
      expect(response.body).to include("Showing 5–5 of 5 entries")
      expect(response.body).not_to include("Hours per month")
      expect(Nokogiri::HTML(response.body).at_css("[aria-current=page]").text).to eq("3")
    end

    it "clamps out-of-range pages" do
      get time_entries_path(page: 99)
      expect(todos).to eq([ "Entry 1" ])
      get time_entries_path(page: -1)
      expect(todos).to eq([ "Entry 5", "Entry 4" ])
    end
  end

  it "keeps 200 entries per page by default" do
    expect(TimeEntriesController::PER_PAGE).to eq(200)
  end

  describe "create" do
    it "creates an entry with automatic hours" do
      expect {
        post time_entries_path, params: { time_entry: { log_date: "2026-11-09", todo: "Write specs" } }
      }.to change(user.time_entries, :count).by(1)
      expect(response).to redirect_to(time_entries_path)
      expect(user.time_entries.last.hours).to eq(BigDecimal("7.6190"))
    end

    it "ignores a hand-entered hours value" do
      post time_entries_path, params: { time_entry: { log_date: "2026-11-09", todo: "x", hours: 99 } }
      expect(user.time_entries.last.hours).to eq(BigDecimal("7.6190"))
    end

    it "re-renders with errors when invalid" do
      post time_entries_path, params: { time_entry: { log_date: "", todo: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Todo can&#39;t be blank")
    end
  end

  describe "quick add for today" do
    it "always logs against today" do
      post today_entry_path, params: { time_entry: { todo: "Standup", log_date: "2020-01-01" } }
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Logged for 13 Nov 2026.")
      expect(user.time_entries.last.log_date).to eq(Date.new(2026, 11, 13))
    end

    it "reports errors" do
      post today_entry_path, params: { time_entry: { todo: "" } }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Todo can't be blank")
    end
  end

  describe "edit, update, destroy" do
    let!(:entry) { create(:time_entry, user:, log_date: Date.new(2026, 11, 9), todo: "Original") }

    it "edits an entry" do
      get edit_time_entry_path(entry)
      expect(response.body).to include("Original")
      patch time_entry_path(entry), params: { time_entry: { todo: "Changed", log_date: "2026-11-10" } }
      expect(response).to redirect_to(time_entries_path)
      expect(entry.reload).to have_attributes(todo: "Changed", log_date: Date.new(2026, 11, 10))
    end

    it "re-renders the edit form when invalid" do
      patch time_entry_path(entry), params: { time_entry: { todo: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes an entry" do
      expect { delete time_entry_path(entry) }.to change(TimeEntry, :count).by(-1)
      expect(response).to redirect_to(time_entries_path)
    end

    it "cannot touch another user's entry" do
      other = create(:time_entry)
      get edit_time_entry_path(other)
      expect(response).to have_http_status(:not_found)
      expect { delete time_entry_path(other) }.not_to change(TimeEntry, :count)
    end
  end
end
