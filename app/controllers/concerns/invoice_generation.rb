# Turns the Generate invoice form into Invoice.generate_for / generate_for_range. Shared by the app and the admin.
#   period=YYYY-MM          -> that whole month
#   period=custom (or no period, with from/to) -> from..to, due on due_date
#   items[n][description|quantity|rate] -> optional extra lines (fully blank rows are ignored)
#   tax_rate                -> percent; blank uses the user's default
module InvoiceGeneration
  extend ActiveSupport::Concern

  private
    def generate_invoice_for(user)
      options = { items: extra_invoice_items, tax_rate: params[:tax_rate].presence }
      # The selected period decides; from/to alone (no period) also means custom dates.
      if params[:period] == "custom" || (params[:period].blank? && (params[:from].present? || params[:to].present?))
        Invoice.generate_for_range(user, Date.iso8601(params[:from].to_s), Date.iso8601(params[:to].to_s),
                                   due_date: Date.iso8601(params[:due_date].to_s), **options)
      else
        Invoice.generate_for(user, Date.strptime(params[:period].to_s, "%Y-%m"), **options)
      end
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
