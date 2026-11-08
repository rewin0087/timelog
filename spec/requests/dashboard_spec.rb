require "rails_helper"

RSpec.describe "Dashboard" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "shows this week's entries by default" do
    create(:time_entry, user:, log_date: Date.new(2026, 11, 10), todo: "This week task")
    create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Last week task")
    get root_path
    expect(response.body).to include("This week (09 Nov – 15 Nov)", "This week task")
    expect(response.body).not_to include("Last week task")
  end

  it "shows a month with navigation" do
    create(:time_entry, user:, log_date: Date.new(2026, 10, 5), todo: "October task")
    get root_path(view: "month", month: "2026-10")
    expect(response.body).to include("October 2026", "October task", "month=2026-09", "month=2026-11")
  end

  describe "activity display" do
    before do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 13), todo: "Timeline task")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 9), todo: "Earlier task")
    end

    let(:html) { Nokogiri::HTML(response.body) }

    it "shows a table by default with a switch to the timeline" do
      get root_path
      expect(html.css("table.rtable")).to be_present
      expect(html.css(".activity-timeline")).to be_empty
      expect(html.at_css("a.tab.active[aria-pressed=true]", text: "Table")).to be_present
    end

    it "shows a timeline grouped by day, today marked, and remembers the choice" do
      get root_path(display: "timeline")
      days = html.css(".activity-timeline-day")
      expect(days.size).to eq(2)
      expect(days.first.text).to include("Mon, 09 Nov", "Earlier task", "1 activity")
      expect(html.css(".activity-timeline-day.is-today").text).to include("Fri, 13 Nov", "Today", "Timeline task")
      expect(html.css("table.rtable")).to be_empty

      get root_path(view: "month", month: "2026-11")
      expect(Nokogiri::HTML(response.body).css(".activity-timeline")).to be_present

      get root_path(display: "table")
      expect(Nokogiri::HTML(response.body).css(".activity-timeline")).to be_empty
    end

    it "keeps the month when switching display" do
      get root_path(view: "month", month: "2026-10")
      expect(response.body).to include("display=timeline&amp;month=2026-10&amp;view=month")
    end

    it "ignores unknown displays" do
      get root_path(display: "bogus")
      expect(html.css("table.rtable")).to be_present
    end
  end

  it "falls back to the current month for a bad month param" do
    get root_path(view: "month", month: "garbage")
    expect(response.body).to include("<h2>November 2026</h2>")
  end

  describe "current month progress" do
    before do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3))
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3))
      get root_path
    end

    let(:html) { Nokogiri::HTML(response.body) }

    def kpi(label) = html.css(".kpi").find { |k| k.text.include?(label) }.css(".kpi-value").text.strip

    it "shows hours logged, hours left, activities, and missed weekdays" do
      expect(response.body).to include("November 2026 progress", "21 weekdays · 160h target")
      expect(kpi("Hours logged")).to eq("15.24h")
      expect(kpi("Hours left to log")).to eq("144.76h")
      expect(kpi("Activities logged")).to eq("3")
      expect(kpi("Missed weekdays")).to eq("7")
    end

    it "flags being behind the expected hours" do
      expect(html.css(".badge-warn").text).to include("behind")
    end

    it "draws one column per day of the month" do
      chart = html.css("figure.chart-dense").first
      expect(chart.css(".chart-col").size).to eq(30)
      expect(chart.css(".chart-bar.tone-missed").size).to eq(7)
      expect(chart.css(".chart-col.is-today")).to be_present
    end
  end

  describe "last 3 months" do
    it "shows hours per month against 160h with weekday counts and status" do
      (Date.new(2026, 10, 1)..Date.new(2026, 10, 31)).reject(&:on_weekend?).each { |d| create(:time_entry, user:, log_date: d) }
      get root_path
      html = Nokogiri::HTML(response.body)
      rows = html.css(".chart-grid-2 .card").first.css(".mini-table tbody tr").map { |r| r.css("td").map { |c| c.text.strip } }
      expect(rows).to eq([
        [ "Oct 2026", "22", "160h", "22/22", "✓ 160h complete" ],
        [ "Sep 2026", "22", "0h", "0/22", "! 160h short" ],
        [ "Aug 2026", "21", "0h", "0/21", "! 160h short" ]
      ])
    end
  end

  describe "hours settings" do
    it "explains the fixed target in the hero and progress header" do
      user.update!(monthly_hours: 168)
      get root_path
      expect(response.body).to include("168h ÷ 21 weekdays", "8h per day", "21 weekdays · 168h target")
    end

    it "shows no target, weekday capacity, and no target line in daily mode" do
      user.update!(hours_mode: "daily")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2))
      get root_path
      html = Nokogiri::HTML(response.body)
      expect(response.body).to include("21 weekdays · no monthly target, up to 168h")
      expect(html.css(".kpi").find { |k| k.text.include?("Hours logged") }.css(".kpi-value").text.strip).to eq("8h")
      last3 = html.css(".chart-grid-2 .card").first
      expect(last3.css(".chart-target")).to be_empty
      expect(last3.at_css("h2").text).to include("hours logged")
    end
  end

  describe "holidays" do
    it "counts holiday kinds for this month and the previous 3" do
      create(:time_entry, user:, log_date: Date.new(2026, 11, 2), todo: "Public holiday")
      create(:time_entry, user:, log_date: Date.new(2026, 10, 30), todo: "Special non-working holiday")
      create(:time_entry, user:, log_date: Date.new(2026, 8, 21), todo: "Holiday")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 3), todo: "Sick leave")
      create(:time_entry, user:, log_date: Date.new(2026, 11, 4), todo: "Absent")
      get root_path
      table = Nokogiri::HTML(response.body).css(".chart-grid-2 .card")[1].css(".mini-table")
      rows = table.css("tbody tr").map { |r| r.css("td").map { |c| (c.at_css(".th-long") || c).text.strip } }
      expect(rows).to eq([
        [ "Nov 2026", "1", "0", "0", "1", "1", "3" ], [ "Oct 2026", "0", "1", "0", "0", "0", "1" ],
        [ "Sep 2026", "0", "0", "0", "0", "0", "0" ], [ "Aug 2026", "0", "0", "1", "0", "0", "1" ]
      ])
      expect(table.css("tfoot td").map { |c| c.text.strip }).to eq(%w[Total 1 1 1 1 1 5])
    end
  end
end
