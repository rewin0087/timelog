class Admin::InvoicesController < Admin::BaseController
  before_action :set_user
  before_action -> { require_permission!(:create) }, only: :create
  before_action -> { require_permission!(:destroy) }, only: :destroy

  def index
    @invoices = @user.invoices.order(period_start: :desc)
    @periods = (0..11).map { |i| Date.current.beginning_of_month.prev_month(i) }
    @invoice_months = TimeStats.new(@user).invoice_months(12)
    @missing = @user.missing_invoice_fields
    @range_from, @range_to, @range_due = Invoice.suggested_range(@user)
  end

  def create
    invoice =
      if params[:from].present? || params[:to].present?
        Invoice.generate_for_range(@user, Date.iso8601(params[:from].to_s), Date.iso8601(params[:to].to_s),
                                   due_date: Date.iso8601(params[:due_date].to_s))
      else
        Invoice.generate_for(@user, Date.strptime(params[:period].to_s, "%Y-%m"))
      end
    redirect_to admin_user_invoices_path(@user), notice: "Invoice #{invoice.code} for #{invoice.period_label} generated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_user_invoices_path(@user), alert: "#{e.record.errors.full_messages.to_sentence}."
  rescue ArgumentError
    redirect_to admin_user_invoices_path(@user), alert: "Pick a valid month, or a valid date range and due date."
  end

  def show
    invoice = @user.invoices.find(params[:id])
    send_data InvoicePdf.new(invoice).render, filename: invoice.filename, type: "application/pdf",
              disposition: params[:inline].present? ? "inline" : "attachment"
  end

  def destroy
    invoice = @user.invoices.find(params[:id])
    invoice.destroy
    redirect_to admin_user_invoices_path(@user), notice: "Invoice #{invoice.code} deleted.", status: :see_other
  end

  private
    def set_user = @user = User.find(params[:user_id])
end
