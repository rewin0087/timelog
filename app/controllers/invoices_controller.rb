class InvoicesController < ApplicationController
  def index
    @invoices = Current.user.invoices.order(period_start: :desc)
    @default_period = Invoice.default_period
    @periods = (0..11).map { |i| Date.current.beginning_of_month.prev_month(i) }
    @range_from, @range_to, @range_due = Invoice.suggested_range(Current.user)
    @invoice_months = TimeStats.new(Current.user).invoice_months(12)
  end

  def create
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
              filename: invoice.filename, type: "application/pdf", disposition: params[:inline].present? ? "inline" : "attachment"
  end
end
