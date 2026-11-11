# A document the assistant attached to a reply (ChatMessage#attachments), ready to show as a card with
# preview and download buttons:
#   invoice        a saved invoice (looked up for the conversation's user; left out once deleted)
#   invoice_draft  a month's invoice that isn't saved yet: Preview never saves it, Download (save_url) does.
#                  Once that month's invoice is saved, the card shows the saved invoice instead.
#   report         the time log report PDF for a date range (never stored; built when opened)
class ChatAttachment < Data.define(:kind, :title, :details, :url, :save_url)
  def self.for(message)
    user = message.conversation.user
    message.attachments.filter_map { |data| build(user, data) }
  end

  def self.build(user, data)
    case data["kind"]
    when "invoice" then (invoice = user.invoices.find_by(id: data["invoice_id"])) && invoice_card(invoice)
    when "invoice_draft" then draft_card(InvoiceDraft.new(user, Date.strptime(data["month"].to_s, "%Y-%m"), refresh: data["refresh"]))
    when "report" then report_card(Date.iso8601(data["from"].to_s), Date.iso8601(data["to"].to_s))
    end
  rescue Date::Error
    nil
  end

  def self.invoice_card(invoice)
    new(kind: "invoice", title: "Invoice #{invoice.code} · #{invoice.period_label}",
        details: "#{format('%.2f', invoice.hours)}h · due #{invoice.due_date.strftime('%-d %b %Y')}",
        url: routes.invoice_path(invoice), save_url: nil)
  end

  def self.draft_card(draft)
    return invoice_card(draft.invoice) if draft.saved?
    invoice = draft.invoice
    params = draft.refresh? ? { refresh: 1 } : {}
    new(kind: "invoice", title: "Draft invoice #{invoice.code} · #{invoice.period_label}",
        details: "#{format('%.2f', invoice.hours)}h · not saved yet: Download saves #{draft.refresh? ? 'the update' : 'it'}",
        url: routes.invoice_draft_path(draft.param, params), save_url: routes.invoice_draft_path(draft.param, params.merge(format: nil)))
  end

  def self.report_card(from, to)
    whole_month = from == from.beginning_of_month && to == from.end_of_month
    label = whole_month ? from.strftime("%B %Y") : "#{from.strftime('%-d %b')} – #{to.strftime('%-d %b %Y')}"
    params = whole_month ? { period: "month", month: from.strftime("%Y-%m") } : { period: "custom", from: from.iso8601, to: to.iso8601 }
    new(kind: "report", title: "Time log report · #{label}", details: "PDF of the time logs for this period",
        url: routes.export_report_path(params), save_url: nil)
  end

  def self.routes = Rails.application.routes.url_helpers
  private_class_method :build, :invoice_card, :draft_card, :report_card, :routes

  def draft? = save_url.present?
  def icon = kind == "invoice" ? "🧾" : "📄"
end
