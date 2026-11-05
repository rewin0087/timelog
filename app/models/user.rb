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

  AUTO_LOCK_OPTIONS = { "1 minute" => 1, "5 minutes" => 5, "15 minutes" => 15, "30 minutes" => 30, "1 hour" => 60, "Never" => 0 }.freeze
  validates :auto_lock_minutes, inclusion: { in: AUTO_LOCK_OPTIONS.values }
  validates :lock_pin, format: { with: /\A\d{4,8}\z/, message: "must be 4 to 8 digits" }, confirmation: true, allow_nil: true
  validate :lock_pin_not_trivial, if: -> { lock_pin.present? }

  def lock_configured? = lock_pin_digest.present?
  def auto_lock? = auto_lock_minutes.positive?

  INVOICE_FIELDS = {
    address: "Address", hourly_rate: "Hourly rate", bank_account_name: "Bank account name",
    bank_account_number: "Bank account number", bank_name: "Bank name", bank_swift: "SWIFT"
  }.freeze

  def missing_invoice_fields
    INVOICE_FIELDS.reject { |attr, _| self[attr].present? }.values
  end

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
