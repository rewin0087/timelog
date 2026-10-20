class Invoice < ApplicationRecord
  MONTHLY_HOURS = 160

  belongs_to :user

  validates :number, :period, :period_start, :period_end, :invoice_date, :due_date, :currency, presence: true
  validates :hours, :rate, numericality: { greater_than_or_equal_to: 0 }
  validate :range_within_one_month, :no_overlap, if: -> { period_start && period_end }
  validate :due_after_invoice_date, if: -> { due_date && invoice_date }

  scope :overlapping, ->(from, to) { where("period_start <= ? AND period_end >= ?", to, from) }

  # Creates (or refreshes) the invoice for the whole month containing `month`.
  def self.generate_for(user, month)
    generate_for_range(user, month.beginning_of_month, month.end_of_month)
  end

  # Creates (or refreshes) the invoice for `from`..`to`, which must sit inside one month.
  # Bills the fixed MONTHLY_HOURS prorated by the weekdays in the range, independent of what is logged.
  # Dated the last day of the range. Due on `due_date` when given, otherwise on the user's
  # configured due day of the following month.
  def self.generate_for_range(user, from, to, due_date: nil)
    invoice = user.invoices.find_or_initialize_by(period_start: from, period_end: to)
    invoice.assign_attributes(
      period: from.beginning_of_month,
      invoice_date: to,
      due_date: due_date || user.invoice_due_date_after(to),
      hours: hours_for(from, to),
      rate: user.hourly_rate,
      currency: user.currency
    )
    invoice.number ||= (user.invoices.maximum(:number) || 0) + 1
    invoice.save!
    invoice
  end

  # Share of MONTHLY_HOURS for the weekdays in `from`..`to` (same split as TimeEntry.daily_hours_for).
  def self.hours_for(from, to)
    weekdays = (from..to).count { |d| !d.on_weekend? }
    (MONTHLY_HOURS.to_d * weekdays / TimeEntry.weekdays_in_month(from)).round(2)
  end

  # Latest month that has finished (or finishes today).
  def self.default_period(today = Date.current)
    today == today.end_of_month ? today.beginning_of_month : today.prev_month.beginning_of_month
  end

  def full_month? = period_start == period.beginning_of_month && period_end == period.end_of_month
  def code = format("INV-%03d", number)
  def amount = (hours * rate).round(2)

  def period_label
    return period.strftime("%B %Y") if full_month?
    "#{period_start.strftime('%-d')}–#{period_end.strftime('%-d %B %Y')}"
  end

  def filename
    slug = full_month? ? period.strftime("%Y-%m") : "#{period_start.iso8601}-to-#{period_end.iso8601}"
    "invoice-#{user.name.parameterize}-#{slug}.pdf"
  end

  private

  def range_within_one_month
    if period_start > period_end
      errors.add(:base, "Start date must be on or before the end date")
    elsif period_start.beginning_of_month != period_end.beginning_of_month
      errors.add(:base, "Start and end dates must be in the same month")
    end
  end

  def due_after_invoice_date
    errors.add(:base, "Due date can't be before the invoice date (#{invoice_date.strftime('%d %b %Y')})") if due_date < invoice_date
  end

  def no_overlap
    clash = user.invoices.where.not(id: id).overlapping(period_start, period_end).order(:period_start).first
    errors.add(:base, "#{clash.code} already covers #{clash.period_label}") if clash
  end
end
