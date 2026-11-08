class InvoicesController < ApplicationController
  include InvoiceGeneration

  def index
    @invoices = Current.user.invoices.includes(:items).order(period_start: :desc)
    @default_period = Invoice.default_period
    @periods = (0..11).map { |i| Date.current.beginning_of_month.prev_month(i) }
    @range_from, @range_to, @range_due = Invoice.suggested_range(Current.user)
    @invoice_months = TimeStats.new(Current.user).invoice_months(12)
  end

  def create
    invoice = generate_invoice_for(Current.user)
    redirect_to invoices_path, notice: invoice_generated_notice(invoice)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to invoices_path, alert: "#{e.record.errors.full_messages.to_sentence}."
  rescue ArgumentError
    redirect_to invoices_path, alert: "Pick a valid month, or a valid date range and due date."
  end

  def preview
    send_invoice_preview(Current.user)
  end

  def show
    invoice = Current.user.invoices.find(params[:id])
    send_data InvoicePdf.new(invoice).render,
              filename: invoice.filename, type: "application/pdf", disposition: params[:inline].present? ? "inline" : "attachment"
  end
end
