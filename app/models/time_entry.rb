class TimeEntry < ApplicationRecord
  belongs_to :user

  validates :log_date, :todo, presence: true

  after_save { rebalance_day(log_date); rebalance_day(log_date_before_last_save) if saved_change_to_log_date? }
  after_destroy { rebalance_day(log_date) }

  scope :between, ->(from, to) { where(log_date: from..to) }
  scope :chronological, -> { order(:log_date, :created_at) }

  def self.weekdays_in_month(date)
    (date.beginning_of_month..date.end_of_month).count { |d| !d.on_weekend? }
  end

  private

  # A day always adds up to one day's worth of hours (User#daily_hours_for), shared equally by that day's todos.
  def rebalance_day(date)
    return unless date
    day = user.time_entries.where(log_date: date)
    count = day.count
    day.update_all(hours: user.daily_hours_for(date) / count) if count.positive?
  end
end
