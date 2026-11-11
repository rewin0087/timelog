class TimelogAgent
  module Tools
    # Prepares a month's invoice as a draft (InvoiceDraft) and attaches it to the reply. Nothing is saved here:
    # the user previews the draft as often as they like, and only its Download button saves it. A month that
    # already has its invoice shows that one, unless refresh is asked for (an updated draft of it).
    class PrepareInvoice < Base
      tool "prepare_invoice",
           description: "Prepare the invoice for a whole month (default: the current month) as a draft the user can preview; " \
                        "nothing is saved until they press Download under your reply. If that month already has a saved " \
                        "invoice it is shown as it is; pass refresh: true for a draft that updates its hours from the latest logs.",
           properties: {
             month: { type: "string", description: "The month, YYYY-MM. Omit for the current month." },
             refresh: { type: "boolean", description: "Draft an update of an existing invoice's hours from the latest logs" }
           }

      def call(args)
        month = month_arg(args["month"])
        invalid!("#{month.strftime('%B %Y')} hasn't started yet") if month > today
        draft = InvoiceDraft.new(user, month, refresh: args["refresh"] == true)
        return { error: draft.errors.to_sentence } if draft.errors.any?

        if draft.saved?
          attach("invoice", invoice_id: draft.invoice.id)
        else
          attach("invoice_draft", month: draft.param, refresh: draft.refresh?)
        end
        details(draft.invoice).merge(status: status(draft), note: note(month)).compact
      end

      private

      def status(draft)
        return "already saved; shown as it is" if draft.saved?
        draft.refresh? ? "draft update of the saved invoice (saved only when the user presses Download)" : "draft (saved only when the user presses Download)"
      end

      def note(month) = ("The month isn't over: the hours are those logged so far." if month.end_of_month >= today)

      def details(invoice)
        {
          number: invoice.code, period: invoice.period_label,
          invoice_date: invoice.invoice_date.iso8601, due_date: invoice.due_date.iso8601,
          hours: invoice.hours.to_f, hours_basis: Invoice::HOURS_BASES.fetch(invoice.hours_basis),
          rate: invoice.rate.to_f, currency: invoice.currency, extra_items: invoice.items.size,
          tax: invoice.tax_amount.to_f, total: invoice.amount.to_f
        }
      end
    end
  end
end
