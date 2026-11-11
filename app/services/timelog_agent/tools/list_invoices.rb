class TimelogAgent
  module Tools
    # The user's invoices, newest first, with their amounts.
    class ListInvoices < Base
      LIMIT = 36

      tool "list_invoices",
           description: "The user's invoices, newest first: number, period, dates, hours, rate, extra items, tax and total. " \
                        "Optionally only those for one year.",
           properties: { year: { type: "integer", description: "Only invoices for this year" } }

      def call(args)
        scope = user.invoices.includes(:items).order(period_start: :desc)
        scope = scope.where(period: Date.new(args["year"].to_i).all_year) if args["year"].present?
        invoices = scope.limit(LIMIT).to_a
        { count: invoices.size, invoices: invoices.map { |i| invoice_row(i) } }
      end

      private

      def invoice_row(invoice)
        {
          number: invoice.code, period: invoice.period_label,
          invoice_date: invoice.invoice_date.iso8601, due_date: invoice.due_date.iso8601,
          hours: invoice.hours.to_f, hours_basis: Invoice::HOURS_BASES.fetch(invoice.hours_basis),
          rate: invoice.rate.to_f, currency: invoice.currency,
          extra_items: invoice.items.map { |it| { description: it.description, quantity: it.quantity.to_f, rate: it.rate.to_f } }.presence,
          tax_rate_percent: invoice.tax_rate.to_f, subtotal: invoice.subtotal.to_f, tax: invoice.tax_amount.to_f, total: invoice.amount.to_f
        }.compact
      end
    end
  end
end
