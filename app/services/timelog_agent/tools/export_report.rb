class TimelogAgent
  module Tools
    # Prepares the time log report PDF (the same one as Export report) for a month or a date range, and
    # attaches it to the reply. Nothing is saved: the PDF is built when it's previewed or downloaded.
    class ExportReport < Base
      MAX_RANGE_DAYS = 366

      tool "export_report",
           description: "Prepare the time log report PDF for a month (default: the current month) or a date range, and show " \
                        "it with preview and download buttons. Returns the totals in the report.",
           properties: {
             month: { type: "string", description: "The month, YYYY-MM. Omit for the current month (or when using from/to)." },
             from: { type: "string", description: "First day of a custom range, YYYY-MM-DD" },
             to: { type: "string", description: "Last day of a custom range, YYYY-MM-DD" }
           }

      def call(args)
        from, to = range(args)
        invalid!("Reports can cover at most #{MAX_RANGE_DAYS} days") if (to - from).to_i >= MAX_RANGE_DAYS

        entries = user.time_entries.between(from, to)
        attach("report", from: from.iso8601, to: to.iso8601)
        { from: from.iso8601, to: to.iso8601, entries: entries.count, days_logged: entries.distinct.count(:log_date),
          hours: hours(entries.sum(:hours)) }
      end

      private

      def range(args)
        if args["from"].present? || args["to"].present?
          [ Date.iso8601(args["from"].to_s), Date.iso8601(args["to"].to_s) ].minmax
        else
          month = month_arg(args["month"])
          [ month, month.end_of_month ]
        end
      end
    end
  end
end
