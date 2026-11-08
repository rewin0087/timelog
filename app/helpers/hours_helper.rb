# Wording for the user's hours rule: a fixed monthly target (default 160h) or no target (8h per logged weekday).
module HoursHelper
  # Value for a chart's dashed target line: the fixed monthly target, or none without one.
  def monthly_target_line(user) = user.fixed_target? ? user.monthly_target : nil

  # "160h target" / "no monthly target"
  def target_summary(user) = user.fixed_target? ? "#{fmt_hours(user.monthly_target)} target" : "no monthly target"

  # One sentence explaining how a day's hours are worked out in `date`'s month.
  def hours_rule(user, date = Date.current)
    if user.fixed_target?
      safe_join([ "Hours are set automatically: #{fmt_hours(user.monthly_target)} ÷ #{TimeEntry.weekdays_in_month(date)} weekdays = ",
                  tag.strong("#{fmt_hours(user.daily_hours_for(date.beginning_of_month.next_weekday))} per day"),
                  " this month. Todos added on the same day share that day's hours." ])
    else
      safe_join([ "No monthly target: each logged weekday counts ", tag.strong("#{User::DAILY_HOURS}h"),
                  ", shared by that day's todos. Weekends count 0h." ])
    end
  end

  # Status badge text for a finished month.
  def month_complete_label(user, month)
    user.fixed_target? ? "✓ #{fmt_hours(month.billable_target)} complete" : "✓ Every weekday logged"
  end
end
