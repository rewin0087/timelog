class Invoice < ApplicationRecord
  MONTHLY_HOURS = User::DEFAULT_MONTHLY_HOURS

  MAX_ITEMS = 8 # what fits on the one-page PDF

  # How the hours are worked out. Without a monthly target only "logged" applies.
  HOURS_BASES = {
    "logged" => "From time logs",
    "target" => "Fixed monthly rate (skip time logs)"
  }.freeze

  belongs_to :user
  has_many :items, -> { order(:position, :id) }, class_name: "InvoiceItem", inverse_of: :invoice, dependent: :delete_all, validate: false

  validates :number, :period, :period_start, :period_end, :invoice_date, :due_date, :currency, presence: true
  validates :hours, :rate, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :items_valid
  validate :range_within_one_month, :no_overlap, if: -> { period_start && period_end }
  validate :due_after_invoice_date, if: -> { due_date && invoice_date }
  validates :hours_basis, inclusion: { in: HOURS_BASES.keys }
  validate :hours_logged, if: -> { hours_basis == "logged" && hours&.zero? }

  scope :overlapping, ->(from, to) { where("period_start <= ? AND period_end >= ?", to, from) }

  # Creates (or refreshes) the invoice for the whole month containing `month`.
  def self.generate_for(user, month, **options)
    generate_for_range(user, month.beginning_of_month, month.end_of_month, **options)
  end

  # Creates (or refreshes) the invoice for `from`..`to`, which must sit inside one month.
  # Hours come from Invoice.hours_for, using `hours_basis` (blank uses the user's default; see .hours_basis_for).
  # Dated the last day of the range. Due on `due_date` when given, otherwise on the user's
  # configured due day of the following month.
  # `items` are optional extra lines ({ description:, quantity:, rate: }); they replace any the invoice had.
  # `tax_rate` (percent) defaults to the user's tax rate.
  # `design`/`color` pick the PDF look (blank uses the user's invoice defaults, see PdfStyle).
  def self.generate_for_range(user, from, to, due_date: nil, items: [], tax_rate: nil, design: nil, color: nil, hours_basis: nil)
    invoice = user.invoices.find_or_initialize_by(period_start: from, period_end: to)
    invoice.assign_attributes(attributes_for(user, from, to, due_date:, tax_rate:, design:, color:, hours_basis:))
    invoice.number ||= (user.invoices.maximum(:number) || 0) + 1
    transaction do
      invoice.items.delete_all if invoice.persisted?
      invoice.items.reset
      items.each_with_index { |item, i| invoice.items.build(item.to_h.symbolize_keys.slice(:description, :quantity, :rate).merge(position: i)) }
      invoice.save!
    end
    invoice
  end

  # An unsaved invoice exactly as generate_for_range would save it, for previewing the PDF before generating.
  def self.preview_for_range(user, from, to, due_date: nil, items: [], tax_rate: nil, design: nil, color: nil, hours_basis: nil)
    existing = user.invoices.find_by(period_start: from, period_end: to)
    invoice = new(attributes_for(user, from, to, due_date:, tax_rate:, design:, color:, hours_basis:)
                    .merge(user:, period_start: from, period_end: to, number: existing&.number || (user.invoices.maximum(:number) || 0) + 1))
    invoice.id = existing&.id # so refreshing an existing invoice doesn't count as an overlap
    items.each_with_index { |item, i| invoice.items.build(item.to_h.symbolize_keys.slice(:description, :quantity, :rate).merge(position: i)) }
    invoice
  end

  def self.attributes_for(user, from, to, due_date:, tax_rate:, design:, color:, hours_basis:)
    style = PdfStyle.new(:invoice, design: [ design, user.invoice_design ], color: [ color, user.invoice_color ])
    basis = hours_basis_for(user, hours_basis)
    { period: from.beginning_of_month, invoice_date: to, due_date: due_date || user.invoice_due_date_after(to),
      hours: hours_for(user, from, to, basis:), hours_basis: basis, rate: user.hourly_rate, currency: user.currency,
      tax_rate: tax_rate.presence || user.tax_rate, design: style.design, color: style.color }
  end
  private_class_method :attributes_for

  # The basis to use: the requested one, else the user's default; always "logged" without a monthly target.
  def self.hours_basis_for(user, requested = nil)
    return "logged" if user.no_target?
    [ requested, user.invoice_hours_basis ].map(&:to_s).find { |basis| HOURS_BASES.key?(basis) } || "logged"
  end

  # Hours to bill for `from`..`to`:
  #   logged -> the billable hours logged in the range (unpaid leave, absent, and days not logged add nothing)
  #   target -> the fixed monthly target prorated by the weekdays in the range, skipping time logs
  def self.hours_for(user, from, to, basis: hours_basis_for(user))
    return user.time_entries.between(from, to).sum(:hours).round(2) if basis == "logged"
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
  # The hours charge (hours x rate), then extra items, tax, and the total due.
  def service_amount = (hours * rate).round(2)
  def items_amount = items.sum(&:amount)
  def subtotal = service_amount + items_amount
  def tax_amount = (subtotal * tax_rate / 100).round(2)
  def amount = subtotal + tax_amount
  def tax? = tax_rate.positive?
  def fixed_rate? = hours_basis == "target"
  def style = PdfStyle.new(:invoice, design: design, color: color)

  def period_label
    return period.strftime("%B %Y") if full_month?
    "#{period_start.strftime('%-d')}–#{period_end.strftime('%-d %B %Y')}"
  end

  def filename
    slug = full_month? ? period.strftime("%Y-%m") : "#{period_start.iso8601}-to-#{period_end.iso8601}"
    "invoice-#{user.name.parameterize}-#{slug}.pdf"
  end

  private

  def items_valid
    errors.add(:base, "Up to #{MAX_ITEMS} extra items fit on an invoice") if items.size > MAX_ITEMS
    items.each_with_index do |item, i|
      next if item.valid?
      errors.add(:base, "Extra item #{i + 1}: #{item.errors.full_messages.to_sentence.downcase}")
    end
  end

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
