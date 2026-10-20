class InvoicesController < ApplicationController
  def index
    @invoices = Current.user.invoices.order(period_start: :desc)
    @default_period = Invoice.default_period
    @periods = (0..11).map { |i| Date.current.beginning_of_month.prev_month(i) }
    @missing = Current.user.missing_invoice_fields
    @range_from, @range_to = suggested_range
    @range_due = Current.user.invoice_due_date_after(@range_to)
  end

  def create
    missing = Current.user.missing_invoice_fields
    if missing.any?
      return redirect_to edit_profile_path, alert: "Complete your profile first: #{missing.to_sentence}."
    end

    invoice =
      if params[:from].present? || params[:to].present?
        Invoice.generate_for_range(Current.user, Date.iso8601(params[:from].to_s), Date.iso8601(params[:to].to_s),
                                   due_date: Date.iso8601(params[:due_date].to_s))
      else
        Invoice.generate_for(Current.user, Date.strptime(params[:period].to_s, "%Y-%m"))
      end
    redirect_to invoices_path, notice: "Invoice #{invoice.code} for #{invoice.period_label} generated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to invoices_path, alert: "#{e.record.errors.full_messages.to_sentence}."
  rescue ArgumentError
    redirect_to invoices_path, alert: "Pick a valid month, or a valid date range and due date."
  end

  def show
    invoice = Current.user.invoices.find(params[:id])
    send_data InvoicePdf.new(invoice).render,
              filename: invoice.filename, type: "application/pdf", disposition: "attachment"
  end

  private

  # Prefills the custom range with the current month's first uninvoiced day up to today
  # (or month end), so the remaining days are one click away after a partial invoice.
  def suggested_range
    today = Date.current
    last_end = Current.user.invoices.where(period: today.beginning_of_month).maximum(:period_end)
    from = last_end && last_end < today.end_of_month ? last_end + 1 : today.beginning_of_month
    to = today >= from ? today : from.end_of_month
    [from, to]
  end
end
