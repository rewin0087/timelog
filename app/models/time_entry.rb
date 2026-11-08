class TimeEntry < ApplicationRecord
  belongs_to :user

  validates :log_date, :todo, presence: true

  after_save { self.class.rebalance_day(user, log_date); self.class.rebalance_day(user, log_date_before_last_save) if saved_change_to_log_date? }
  after_destroy { self.class.rebalance_day(user, log_date) }

  scope :between, ->(from, to) { where(log_date: from..to) }
  scope :chronological, -> { order(:log_date, :created_at) }

  def self.weekdays_in_month(date)
    (date.beginning_of_month..date.end_of_month).count { |d| !d.on_weekend? }
  end

  # A day adds up to one day's worth of hours (User#daily_hours_for), shared equally by its billable todos.
  # Unbillable todos (unpaid leave, absent; see DayKind) get 0 hours, so a day with only those totals 0.
  def self.rebalance_day(user, date)
    return unless date
    day = user.time_entries.where(log_date: date).pluck(:id, :todo)
    billable, unpaid = day.partition { |_, todo| DayKind.billable?(todo) }
    TimeEntry.where(id: unpaid.map(&:first)).update_all(hours: 0) if unpaid.any?
    TimeEntry.where(id: billable.map(&:first)).update_all(hours: user.daily_hours_for(date) / billable.size) if billable.any?
  end

  def billable? = DayKind.billable?(todo)
  def day_kind = DayKind.for(todo)
end
