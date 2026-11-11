# A month's invoice before it's saved, so the assistant can offer it for preview without creating a record.
# Only #save! (the Download button) stores it.
#
#   draft = InvoiceDraft.new(user, Date.new(2026, 11, 1))
#   draft.invoice  # unsaved Invoice for the PDF preview (or the saved one, see #saved?)
#   draft.save!    # creates it; with refresh, updates the existing invoice's hours
#
# Without refresh, a month that already has its invoice just uses that invoice (#saved?), so saving twice never
# makes a second record. With refresh, the existing invoice's number, extra items, tax, due date, hours basis
# and PDF style are kept and only the hours are recalculated from the latest logs.
class InvoiceDraft
  attr_reader :user, :month

  def initialize(user, month, refresh: false)
    @user = user
    @month = month.beginning_of_month
    @refresh = refresh
  end

  def refresh? = @refresh && existing.present?

  # Already saved and nothing to change: show and download the stored invoice.
  def saved? = existing.present? && !refresh?

  def invoice
    @invoice ||= saved? ? existing : Invoice.preview_for_range(user, from, to, **settings)
  end

  def errors = saved? || invoice.valid? ? [] : invoice.errors.full_messages

  def save!
    return existing if saved?
    Invoice.generate_for_range(user, from, to, **settings)
  end

  def param = month.strftime("%Y-%m")

  private

  def from = month
  def to = month.end_of_month

  def existing
    return @existing if defined?(@existing)
    @existing = user.invoices.find_by(period_start: from, period_end: to)
  end

  def settings
    return {} unless refresh?
    { due_date: existing.due_date, tax_rate: existing.tax_rate, design: existing.design, color: existing.color,
      hours_basis: existing.hours_basis,
      items: existing.items.map { |it| { description: it.description, quantity: it.quantity, rate: it.rate } } }
  end
end
