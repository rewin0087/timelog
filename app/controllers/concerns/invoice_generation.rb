# Turns the Generate invoice form into Invoice.generate_for / generate_for_range. Shared by the app and the admin.
#   period=YYYY-MM          -> that whole month
#   period=custom (or no period, with from/to) -> from..to, due on due_date
#   items[n][description|quantity|rate] -> optional extra lines (fully blank rows are ignored)
#   tax_rate                -> percent; blank uses the user's default
#   design, color           -> PDF look; blank uses the user's invoice defaults
module InvoiceGeneration
  extend ActiveSupport::Concern

  private
    def generate_invoice_for(user)
      from, to, due = requested_invoice_period
      Invoice.generate_for_range(user, from, to, due_date: due, **invoice_options)
    end

    # The invoice the form would generate, unsaved, for the PDF preview.
    def preview_invoice_for(user)
      from, to, due = requested_invoice_period
      Invoice.preview_for_range(user, from, to, due_date: due, **invoice_options)
    end

    # Renders the draft PDF, or a short explanation inside the preview when the form isn't valid yet.
    def send_invoice_preview(user)
      invoice = preview_invoice_for(user)
      return render_preview_problem(invoice.errors.full_messages) unless invoice.valid?
      send_data InvoicePdf.new(invoice).render, filename: "draft-#{invoice.filename}", type: "application/pdf",
                disposition: params[:inline].present? ? "inline" : "attachment"
    rescue ArgumentError
      render_preview_problem([ "Pick a valid month, or a valid date range and due date." ])
    end

    def render_preview_problem(messages)
      items = messages.map { |m| "<li>#{ERB::Util.h(m)}</li>" }.join
      render status: :unprocessable_content, layout: false, html: <<~HTML.html_safe
        <!doctype html><meta charset="utf-8"><title>Can't preview yet</title>
        <body style="font:15px/1.5 system-ui,sans-serif;margin:40px;color:#1e1b4b"><h2>Can't preview this invoice yet</h2><ul>#{items}</ul></body>
      HTML
    end

    # [from, to, due_date]: the selected period decides; from/to alone (no period) also means custom dates.
    def requested_invoice_period
      if params[:period] == "custom" || (params[:period].blank? && (params[:from].present? || params[:to].present?))
        [ Date.iso8601(params[:from].to_s), Date.iso8601(params[:to].to_s), Date.iso8601(params[:due_date].to_s) ]
      else
        month = Date.strptime(params[:period].to_s, "%Y-%m")
        [ month.beginning_of_month, month.end_of_month, nil ]
      end
    end

    def invoice_options
      { items: extra_invoice_items, tax_rate: params[:tax_rate].presence, design: params[:design].presence, color: params[:color].presence }
    end

    def extra_invoice_items
      raw = params.permit(items: %i[description quantity rate])[:items]
      list = raw.respond_to?(:values) ? raw.values : Array(raw)
      list.map(&:to_h).reject { |item| item.values.all?(&:blank?) }
    end

    def invoice_generated_notice(invoice)
      extras = [ ("#{invoice.items.size} extra #{'item'.pluralize(invoice.items.size)}" if invoice.items.any?),
                 ("#{invoice.tax_rate.to_s('F').sub(/\.0\z/, '')}% tax" if invoice.tax?) ].compact
      "Invoice #{invoice.code} for #{invoice.period_label} generated#{" with #{extras.to_sentence}" if extras.any?}."
    end
end
