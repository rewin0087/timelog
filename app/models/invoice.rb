class Invoice < ApplicationRecord
  MONTHLY_HOURS = User::DEFAULT_MONTHLY_HOURS

  belongs_to :user

  validates :number, :period, :period_start, :period_end, :invoice_date, :due_date, :currency, presence: true
  validates :hours, :rate, numericality: { greater_than_or_equal_to: 0 }
  validate :range_within_one_month, :no_overlap, if: -> { period_start && period_end }
  validate :due_after_invoice_date, if: -> { due_date && invoice_date }
  validate :hours_logged, if: -> { user&.no_target? && hours&.zero? }

  scope :overlapping, ->(from, to) { where("period_start <= ? AND period_end >= ?", to, from) }

  # Creates (or refreshes) the invoice for the whole month containing `month`.
  def self.generate_for(user, month)
    generate_for_range(user, month.beginning_of_month, month.end_of_month)
  end

  # Creates (or refreshes) the invoice for `from`..`to`, which must sit inside one month.
  # Hours come from Invoice.hours_for (the user's monthly target, or what was logged with no target).
  # Dated the last day of the range. Due on `due_date` when given, otherwise on the user's
  # configured due day of the following month.
  def self.generate_for_range(user, from, to, due_date: nil)
    invoice = user.invoices.find_or_initialize_by(period_start: from, period_end: to)
    invoice.assign_attributes(
      period: from.beginning_of_month,
      invoice_date: to,
      due_date: due_date || user.invoice_due_date_after(to),
      hours: hours_for(user, from, to),
      rate: user.hourly_rate,
      currency: user.currency
    )
    invoice.number ||= (user.invoices.maximum(:number) || 0) + 1
    invoice.save!
    invoice
  end

  # Hours to bill for `from`..`to`:
  #   fixed target -> the user's monthly target prorated by weekdays, whatever was logged
  #   no target    -> the hours actually logged (8h per logged weekday)
  def self.hours_for(user, from, to)
    return user.time_entries.between(from, to).sum(:hours).round(2) if user.no_target?
    weekdays = (from..to).count { |d| !d.on_weekend? }
    (user.monthly_target * weekdays / TimeEntry.weekdays_in_month(from)).round(2)
  end

  # Prefill for a custom invoice: from the current month's first uninvoiced day up to today (or month end),
  # due on the user's due day. Returns [from, to, due].
  def self.suggested_range(user, today = Date.current)
    last_end = user.invoices.where(period: today.beginning_of_month).maximum(:period_end)
    from = last_end && last_end < today.end_of_month ? last_end + 1 : today.beginning_of_month
    to = today >= from ? today : from.end_of_month
    [ from, to, user.invoice_due_date_after(to) ]
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

  def hours_logged
    errors.add(:base, "Nothing is logged between #{period_start.strftime('%-d %b')} and #{period_end.strftime('%-d %b %Y')}, so there are no hours to bill")
  end

  def no_overlap
    clash = user.invoices.where.not(id: id).overlapping(period_start, period_end).order(:period_start).first
    errors.add(:base, "#{clash.code} already covers #{clash.period_label}") if clash
  end
end
