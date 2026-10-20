class TimeEntry < ApplicationRecord
  belongs_to :user

  validates :log_date, :todo, presence: true

  after_save { rebalance_day(log_date); rebalance_day(log_date_before_last_save) if saved_change_to_log_date? }
  after_destroy { rebalance_day(log_date) }

  scope :between, ->(from, to) { where(log_date: from..to) }
  scope :chronological, -> { order(:log_date, :created_at) }

  # Hours for one working day = the monthly hours spread over that month's weekdays
  # (20 weekdays -> 8h, 21 -> 7.62h, 22 -> 7.27h). Weekends carry no hours.
  def self.daily_hours_for(date)
    return 0.to_d if date.on_weekend?
    (Invoice::MONTHLY_HOURS.to_d / weekdays_in_month(date)).round(4)
  end

  def self.weekdays_in_month(date)
    (date.beginning_of_month..date.end_of_month).count { |d| !d.on_weekend? }
  end

  private

  # A day always adds up to one day's worth of hours, shared equally by that day's todos.
  def rebalance_day(date)
    return unless date
    day = user.time_entries.where(log_date: date)
    count = day.count
    day.update_all(hours: self.class.daily_hours_for(date) / count) if count.positive?
  end
end
