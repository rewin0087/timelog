class TimelogAgent
  module Tools
    # The time entries in a date range, with totals and the weekdays left unlogged.
    class ListTimeEntries < Base
      MAX_RANGE_DAYS = 366
      MAX_LISTED = 300

      tool "list_time_entries",
           description: "The time entries (todos with hours) logged from one date to another, inclusive, with totals " \
                        "and the weekdays in the range that have nothing logged. Use for a day, week, month or any range " \
                        "(at most #{MAX_RANGE_DAYS} days).",
           properties: {
             from: { type: "string", description: "First day, YYYY-MM-DD" },
             to: { type: "string", description: "Last day, YYYY-MM-DD" }
           },
           required: %w[from to]

      def call(args)
        from, to = [ Date.iso8601(args["from"].to_s), Date.iso8601(args["to"].to_s) ].minmax
        invalid!("Ranges can be at most #{MAX_RANGE_DAYS} days") if (to - from).to_i >= MAX_RANGE_DAYS

        entries = user.time_entries.between(from, to).chronological.to_a
        logged = entries.map(&:log_date).to_set
        {
          from: from.iso8601, to: to.iso8601,
          totals: { hours: hours(entries.sum(&:hours)), entries: entries.size, days_logged: logged.size },
          weekdays_not_logged: unlogged_weekdays(from, to, logged).map(&:iso8601),
          entries: entries.first(MAX_LISTED).map { |e| entry_row(e) },
          truncated: (true if entries.size > MAX_LISTED)
        }.compact
      end

      private

      def entry_row(entry)
        { date: entry.log_date.iso8601, weekday: entry.log_date.strftime("%a"), todo: entry.todo,
          hours: hours(entry.hours), kind: entry.day_kind&.label }.compact
      end
    end
  end
end
