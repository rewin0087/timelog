# Read-only statistics over a user's time entries and invoices, used by the dashboard,
# Manage logs, and Invoices charts. Hours come from the stored per-entry hours, so a
# month's logged hours reach Invoice::MONTHLY_HOURS once every weekday has an entry.
class TimeStats
  # Holidays have no field of their own: they are entries whose todo mentions one of these.
  # Checked in order, so "Special non-working holiday" counts as non-working, not as a plain holiday.
  HOLIDAY_KINDS = [
    [ :public, "Public holiday", /\b(public|regular|national)\s+holiday/i ],
    [ :non_working, "Non-working holiday", /non[\s-]?working/i ],
    [ :holiday, "Holiday", /holiday/i ]
  ].freeze

  Month = Struct.new(:month, :weekdays, :hours, :entries, :days_logged, :weekdays_logged, :holidays, keyword_init: true) do
    def target = Invoice::MONTHLY_HOURS
    def complete? = hours.round(2) >= target
    def remaining = [ target - hours, 0 ].max
    def percent = target.zero? ? 0 : (hours / target * 100).round
    def holiday_days = holidays.values.sum
    def label = month.strftime("%b %Y")
  end

  Day = Struct.new(:date, :hours, :entries, :holiday, keyword_init: true) do
    def weekend? = date.on_weekend?
  end

  def self.holiday_kind(todo)
    HOLIDAY_KINDS.find { |_, _, pattern| todo.to_s.match?(pattern) }&.first
  end

  def self.holiday_label(kind) = HOLIDAY_KINDS.find { |k, _, _| k == kind }&.second

  attr_reader :user, :today

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  # One Month per month from `first` to `last` (any dates inside them), oldest first.
  def months(first, last)
    first = first.beginning_of_month
    last = last.beginning_of_month
    rows = user.time_entries.where(log_date: first..last.end_of_month).pluck(:log_date, :hours, :todo)
    by_month = rows.group_by { |date, _, _| date.beginning_of_month }

    month_list(first, last).map do |month|
      entries = by_month.fetch(month, [])
      dates = entries.map(&:first).uniq
      Month.new(
        month: month,
        weekdays: TimeEntry.weekdays_in_month(month),
        hours: entries.sum { |_, hours, _| hours }.to_d,
        entries: entries.size,
        days_logged: dates.size,
        weekdays_logged: dates.count { |d| !d.on_weekend? },
        holidays: holiday_days(entries)
      )
    end
  end

  def current_month = months(today, today).first

  # The `count` full months before the current one, oldest first.
  def previous_months(count) = months(today.prev_month(count), today.prev_month)

  # Every day of the current month with its hours, entry count, and holiday kind (if any).
  def current_month_days
    from, to = today.beginning_of_month, today.end_of_month
    rows = user.time_entries.where(log_date: from..to).pluck(:log_date, :hours, :todo).group_by(&:first)
    (from..to).map do |date|
      day = rows.fetch(date, [])
      Day.new(date: date, hours: day.sum { |_, h, _| h }.to_d, entries: day.size,
              holiday: day.filter_map { |_, _, todo| self.class.holiday_kind(todo) }.first)
    end
  end

  # Hours that should be logged by the end of today for the month to be on track.
  def expected_to_date
    (today.beginning_of_month..today).sum { |d| TimeEntry.daily_hours_for(d) }
  end

  # Weekdays before today, this month, with nothing logged.
  def missed_weekdays
    logged = user.time_entries.where(log_date: today.beginning_of_month...today).distinct.pluck(:log_date)
    (today.beginning_of_month...today).reject { |d| d.on_weekend? || logged.include?(d) }
  end

  def weekdays_left
    (today..today.end_of_month).count { |d| !d.on_weekend? }
  end

  # Entries per date over the last `weeks` weeks (Monday-aligned), for the activity heatmap.
  def activity(weeks)
    from = today.beginning_of_week - (weeks - 1).weeks
    counts = user.time_entries.where(log_date: from..today).group(:log_date).count
    (from..today.end_of_week).map { |d| [ d, d > today ? nil : counts.fetch(d, 0) ] }
  end

  # Entries per weekday (Mon..Sun) over the last 12 months.
  def entries_by_weekday
    counts = user.time_entries.where(log_date: today.prev_month(11).beginning_of_month..today)
                 .pluck(:log_date).map { |d| d.cwday }.tally
    (1..7).map { |wd| [ Date::ABBR_DAYNAMES[wd % 7], counts.fetch(wd, 0) ] }
  end

  # The most frequent todos (case and whitespace-insensitive), all time.
  def top_tasks(limit = 6)
    user.time_entries.pluck(:todo)
        .group_by { |t| t.squish.downcase }
        .map { |_, todos| [ todos.first.squish, todos.size ] }
        .sort_by { |todo, count| [ -count, todo ] }
        .first(limit)
  end

  def totals
    scope = user.time_entries
    { entries: scope.count, hours: scope.sum(:hours), days: scope.distinct.count(:log_date), since: scope.minimum(:log_date) }
  end

  # Invoiced months, oldest first: billed hours and amount next to what was logged.
  # Partial invoices in the same month are added together.
  def invoice_months(count = 12)
    first = today.prev_month(count - 1).beginning_of_month
    invoices = user.invoices.where(period: first..today.end_of_month).to_a.group_by(&:period)
    logged = months(first, today).index_by(&:month)
    month_list(first, today.beginning_of_month).map do |month|
      list = invoices.fetch(month, [])
      { month: month, billed_hours: list.sum(&:hours), amount: list.sum(&:amount), invoices: list.size,
        currency: list.first&.currency, logged_hours: logged[month].hours }
    end
  end

  private

  def month_list(first, last)
    list = []
    month = first
    while month <= last
      list << month
      month = month.next_month
    end
    list
  end

  # Days per holiday kind; a day counts once even if it has several entries.
  def holiday_days(entries)
    counts = HOLIDAY_KINDS.to_h { |kind, _, _| [ kind, 0 ] }
    entries.group_by(&:first).each_value do |day|
      kind = day.filter_map { |_, _, todo| self.class.holiday_kind(todo) }.first
      counts[kind] += 1 if kind
    end
    counts
  end
end
