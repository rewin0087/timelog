class User < ApplicationRecord
  has_secure_password
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
end
