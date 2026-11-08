# Read-only statistics across every user, for the admin dashboard and users list.
class AdminStats
  attr_reader :today

  def initialize(today: Date.current)
    @today = today
  end

  def month = today.beginning_of_month
  def first_month(count) = today.prev_month(count - 1).beginning_of_month

  def totals
    month_entries = TimeEntry.where(log_date: month..today.end_of_month)
    {
      users: User.count,
      new_users: User.where(created_at: month.beginning_of_day..).count,
      active_users: month_entries.distinct.count(:user_id),
      hours: month_entries.sum(:hours),
      entries: month_entries.count,
      entries_all: TimeEntry.count,
      invoices: Invoice.count,
      pending: User.all.count { |u| !u.onboarded? }
    }
  end

  # [{ month:, hours:, entries:, active_users: }] for the last `count` months, oldest first.
  def months(count = 12)
    rows = TimeEntry.where(log_date: first_month(count)..today.end_of_month).pluck(:log_date, :hours, :user_id)
    by_month = rows.group_by { |date, _, _| date.beginning_of_month }
    month_list(count).map do |m|
      list = by_month.fetch(m, [])
      { month: m, hours: list.sum { |_, h, _| h }, entries: list.size, active_users: list.map(&:third).uniq.size }
    end
  end

  # New sign-ups per month, oldest first.
  def signups(count = 12)
    counts = User.where(created_at: first_month(count).beginning_of_day..).pluck(:created_at).map { |t| t.to_date.beginning_of_month }.tally
    month_list(count).map { |m| { month: m, users: counts.fetch(m, 0) } }
  end

  # Invoices per month with amounts per currency, oldest first.
  def invoices(count = 12)
    list = Invoice.where(period: first_month(count)..today.end_of_month).to_a.group_by(&:period)
    month_list(count).map do |m|
      rows = list.fetch(m, [])
      { month: m, count: rows.size, amounts: rows.group_by(&:currency).transform_values { |r| r.sum(&:amount) } }
    end
  end

  # Total invoiced per currency over the last `count` months, largest first.
  def invoiced_by_currency(count = 12)
    invoices(count).flat_map { |m| m[:amounts].to_a }.each_with_object(Hash.new(0)) { |(cur, amt), h| h[cur] += amt }.sort_by { |_, amt| -amt }
  end

  # Users with the most hours this month: [[user, hours, entries]].
  def top_users(limit = 8)
    rows = TimeEntry.where(log_date: month..today.end_of_month).group(:user_id).pluck(:user_id, Arel.sql("SUM(hours)"), Arel.sql("COUNT(*)"))
    users = User.where(id: rows.map(&:first)).index_by(&:id)
    rows.sort_by { |_, hours, _| -hours }.first(limit).map { |id, hours, count| [ users[id], hours, count ] }
  end

  # This month's hours and entries per user id, plus invoice counts, for the users list.
  def per_user(ids)
    hours = TimeEntry.where(user_id: ids, log_date: month..today.end_of_month).group(:user_id).sum(:hours)
    entries = TimeEntry.where(user_id: ids).group(:user_id).count
    invoices = Invoice.where(user_id: ids).group(:user_id).count
    last_log = TimeEntry.where(user_id: ids).group(:user_id).maximum(:log_date)
    ids.index_with { |id| { hours: hours.fetch(id, 0), entries: entries.fetch(id, 0), invoices: invoices.fetch(id, 0), last_log: last_log[id] } }
  end

  def recent_entries(limit = 8) = TimeEntry.includes(:user).order(created_at: :desc, log_date: :desc, id: :desc).limit(limit)

  private

  def month_list(count) = (0...count).map { |i| first_month(count).next_month(i) }
end
