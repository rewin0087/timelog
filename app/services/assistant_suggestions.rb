# Conversation starters for the assistant (dashboard card and a new chat), picked from the user's own data
# so the most useful one comes first (no AI call: plain checks on the logs and invoices). Around the end of
# a month they offer that month's invoice (as a draft to preview) and time log report.
#
#   AssistantSuggestions.new(user).to_a # => [#<Suggestion label: "Fill in 3 missed days", message: "...">, ...]
class AssistantSuggestions
  Suggestion = Data.define(:label, :message)
  LIMIT = 4
  MONTH_END_DAYS = 3   # the last 3 days of a month count as its end
  MONTH_START_DAYS = 5 # the first 5 days of a month still offer the month just ended

  def self.month_end?(today) = today >= today.end_of_month - (MONTH_END_DAYS - 1)
  def self.month_start?(today) = today.day <= MONTH_START_DAYS

  def initialize(user, today: Date.current, missed_days: nil)
    @user = user
    @today = today
    @missed_days = missed_days || TimeStats.new(user, today:).missed_weekdays
  end

  def to_a
    candidates =
      if self.class.month_end?(today) then [ invoice(today), report(today), log_today, missed ]
      elsif self.class.month_start?(today) then [ log_today, invoice(today.prev_month), report(today.prev_month), missed, hours_left ]
      else [ log_today, missed, uninvoiced_last_month, hours_left, week_summary ]
      end
    candidates.compact.first(LIMIT)
  end

  private

  attr_reader :user, :today, :missed_days

  def log_today
    return if today.on_weekend? || user.time_entries.exists?(log_date: today)
    Suggestion.new("Log what I worked on today", "Help me log what I worked on today.")
  end

  def missed
    return if missed_days.empty?
    days = missed_days.map { |d| d.strftime("%a %-d %b") }
    shown = days.size > 3 ? "#{days.first(3).join(', ')} +#{days.size - 3}" : days.to_sentence
    Suggestion.new("Fill in #{missed_days.size} missed #{'day'.pluralize(missed_days.size)} (#{shown})",
                   "I haven't logged #{days.to_sentence} yet. Help me fill them in.")
  end

  # Preview the month's invoice as a draft (saved only on download), or show it when it's already saved.
  def invoice(month)
    from, to = month.beginning_of_month, month.end_of_month
    return unless user.time_entries.between(from, to).exists?
    name = "#{month.strftime('%B')} #{month.year}"
    if (existing = user.invoices.find_by(period_start: from, period_end: to))
      Suggestion.new("Show #{existing.code} (#{month.strftime('%B')})", "Show me my #{name} invoice.")
    elsif !user.invoices.overlapping(from, to).exists?
      Suggestion.new("Preview #{month.strftime('%B')} invoice", "Prepare my invoice for #{name} so I can preview it.")
    end
  end

  def report(month)
    return unless user.time_entries.between(month.beginning_of_month, month.end_of_month).exists?
    Suggestion.new("#{month.strftime('%B')} time log report", "Export my time log report for #{month.strftime('%B %Y')}.")
  end

  def uninvoiced_last_month
    month = today.prev_month
    from, to = month.beginning_of_month, month.end_of_month
    return unless user.time_entries.between(from, to).exists?
    return if user.invoices.overlapping(from, to).exists?
    Suggestion.new("#{month.strftime('%B')} isn't invoiced yet", "Prepare my invoice for #{month.strftime('%B %Y')} so I can preview it.")
  end

  def hours_left = Suggestion.new("How many hours are left this month?", "How many hours are left this month, and am I on track?")

  def week_summary = Suggestion.new("Summarise my week", "Summarise what I logged this week.")
end
