class TimelogAgent
  module Tools
    # One month's progress against its target, with the counts the model shouldn't work out itself.
    class MonthSummary < Base
      tool "month_summary",
           description: "Progress for one month: hours logged against the month's target, hours left, weekdays logged " \
                        "and missed, holidays/leave, and unpaid days.",
           properties: { month: { type: "string", description: "The month, YYYY-MM" } },
           required: %w[month]

      def call(args)
        month = Date.strptime(args["month"].to_s, "%Y-%m")
        stats = TimeStats.new(user, today:).months(month, month).first
        logged = user.time_entries.between(month, month.end_of_month).distinct.pluck(:log_date).to_set
        ahead = weekdays_still_to_log(month, logged)
        {
          month: stats.label,
          status: status(month),
          hours_logged: hours(stats.hours),
          target_hours: hours(stats.billable_target),
          hours_left: stats.remaining.to_f,
          percent_of_target: stats.percent,
          complete: stats.complete?,
          weekdays_in_month: stats.weekdays,
          weekdays_logged: stats.weekdays_logged,
          weekdays_not_logged_so_far: (month <= today ? unlogged_weekdays(month, month.end_of_month, logged) : []).map(&:iso8601),
          weekdays_still_to_log: ahead.size,
          hours_per_weekday_to_reach_target: (hours(stats.remaining / ahead.size) if ahead.any?),
          hours_per_weekday_logged: hours(user.daily_hours_for(month.next_weekday)),
          entries: stats.entries,
          holidays_and_leave: stats.holidays.transform_keys { |k| TimeStats.holiday_label(k) },
          unpaid_days: stats.unpaid_days,
          invoice: user.invoices.where(period: month).order(:period_start).map { |i| "#{i.code} (#{i.period_label})" }.presence
        }.compact
      end

      private

      def status(month)
        return "future" if month > today
        month == today.beginning_of_month ? "current" : "past"
      end

      # Weekdays still to come this month (today included when it isn't logged yet).
      def weekdays_still_to_log(month, logged)
        (month..month.end_of_month).select { |d| d >= today && !d.on_weekend? && !logged.include?(d) }
      end
    end
  end
end
