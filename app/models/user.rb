class User < ApplicationRecord
  has_secure_password
  has_secure_password :lock_pin, validations: false
  has_many :sessions, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :invoices, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, :email_address, presence: true
  validates :email_address, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :hourly_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :currency, presence: true
  validates :invoice_due_day, numericality: { only_integer: true, in: 1..31 }
  DEFAULT_INVOICE_ITEM = "Consultancy Service"
  validates :invoice_item, presence: true, length: { maximum: 40 }

  # Required on the profile and in onboarding (saved with `context: :invoice_details`), but not at sign-up.
  INVOICE_FIELDS = {
    address: "Address", bill_to_name: "Bill to name", bill_to_address: "Bill to address",
    hourly_rate: "Hourly rate", bank_account_name: "Bank account name",
    bank_account_number: "Bank account number", bank_name: "Bank name", bank_swift: "SWIFT"
  }.freeze
  validates(*INVOICE_FIELDS.keys, presence: true, on: :invoice_details)

  # How logged hours are worked out (see README, "How hours are calculated").
  HOURS_MODES = { "monthly" => "Fixed monthly target", "daily" => "No monthly target (8h per logged weekday)" }.freeze
  DEFAULT_MONTHLY_HOURS = 160
  DAILY_HOURS = 8
  validates :hours_mode, inclusion: { in: HOURS_MODES.keys }
  validates :monthly_hours, numericality: { greater_than: 0, less_than_or_equal_to: 744 }, allow_nil: true

  # Existing logs are re-split whenever the way hours are worked out changes. Invoices keep their stored hours.
  after_update_commit :rebalance_time_entries!, if: -> { saved_change_to_hours_mode? || saved_change_to_monthly_hours? }

  AUTO_LOCK_OPTIONS = { "1 minute" => 1, "5 minutes" => 5, "15 minutes" => 15, "30 minutes" => 30, "1 hour" => 60, "Never" => 0 }.freeze
  validates :auto_lock_minutes, inclusion: { in: AUTO_LOCK_OPTIONS.values }
  validates :lock_pin, format: { with: /\A\d{4,8}\z/, message: "must be 4 to 8 digits" }, confirmation: true, allow_nil: true
  validate :lock_pin_not_trivial, if: -> { lock_pin.present? }

  def fixed_target? = hours_mode == "monthly"
  def no_target? = hours_mode == "daily"

  # The monthly target in fixed mode (blank = 160h); nil when there is no monthly target.
  def monthly_target = fixed_target? ? (monthly_hours.presence || DEFAULT_MONTHLY_HOURS).to_d : nil

  # Hours one working day is worth: the monthly target spread over the month's weekdays
  # (160h / 21 weekdays = 7.619h), or a flat 8h with no monthly target. Weekends carry no hours.
  def daily_hours_for(date)
    return 0.to_d if date.on_weekend?
    return DAILY_HOURS.to_d if no_target?
    (monthly_target / TimeEntry.weekdays_in_month(date)).round(4)
  end

  # Most hours a month can hold: the fixed target, or every weekday at 8h with no target.
  def month_capacity(month) = fixed_target? ? monthly_target : DAILY_HOURS.to_d * TimeEntry.weekdays_in_month(month)

  # Re-splits every logged day with the current hours settings.
  def rebalance_time_entries!
    time_entries.group(:log_date).count.each do |date, count|
      time_entries.where(log_date: date).update_all(hours: daily_hours_for(date) / count)
    end
  end

  def lock_configured? = lock_pin_digest.present?
  def auto_lock? = auto_lock_minutes.positive?

  def missing_invoice_fields
    INVOICE_FIELDS.reject { |attr, _| self[attr].present? }.values
  end

  def invoice_details_complete? = missing_invoice_fields.empty?

  # Onboarding is done once invoices can be generated and the lock screen is set up.
  def onboarded? = invoice_details_complete? && lock_configured?

  # The configured due day in the month after `date`, capped at that month's last day (31 -> 30 Nov).
  def invoice_due_date_after(date)
    month = date.next_month
    month.change(day: [invoice_due_day, month.end_of_month.day].min)
  end

  private
    # Rejects codes like 0000, 1234 or 9876 that are guessed first.
    def lock_pin_not_trivial
      digits = lock_pin.chars.map(&:to_i)
      steps = digits.each_cons(2).map { |a, b| b - a }.uniq
      errors.add(:lock_pin, "is too easy to guess") if steps.size == 1 && steps.first.abs <= 1
    end
end
