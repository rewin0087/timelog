# A month's invoice as a draft (InvoiceDraft): preview the PDF as often as you like without saving anything;
# downloading is what saves it (or reuses the month's saved invoice), then sends the PDF.
class InvoiceDraftsController < ApplicationController
  include InvoiceGeneration

  before_action :set_draft

  # GET /invoice_drafts/2026-11.pdf(?refresh=1)(&inline=1) - the draft PDF; never saves.
  def show
    return render_preview_problem(@draft.errors) if @draft.errors.any?
    invoice = @draft.invoice
    send_data InvoicePdf.new(invoice).render, type: "application/pdf",
              filename: @draft.saved? ? invoice.filename : "draft-#{invoice.filename}",
              disposition: params[:inline].present? ? "inline" : "attachment"
  end

  # POST /invoice_drafts/2026-11(?refresh=1) - saves the invoice, then downloads it.
  def create
    redirect_to invoice_path(@draft.save!)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to invoices_path, alert: "#{e.record.errors.full_messages.to_sentence}."
  end

  private

  def set_draft
    month = Date.strptime(params[:month].to_s, "%Y-%m")
    @draft = InvoiceDraft.new(Current.user, month, refresh: params[:refresh].present?)
  rescue Date::Error
    head :not_found
  end
end
