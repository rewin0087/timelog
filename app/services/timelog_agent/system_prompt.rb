class TimelogAgent
  # The assistant's instructions for one user on one day: who it's talking to, today's date, what it can do,
  # how Time.log works (with this user's hours rules), and how to answer. The wording lives in
  # system_prompt.md.erb next to this file; this class only supplies the values it needs.
  class SystemPrompt
    TEMPLATE = ERB.new(File.read(File.expand_path("system_prompt.md.erb", __dir__)), trim_mode: "-")

    def initialize(user, today: Date.current)
      @user = user
      @today = today
    end

    def to_s = TEMPLATE.result(binding)

    private

    attr_reader :user, :today

    def today_label = "#{today.strftime('%A, %-d %B %Y')} (#{today.iso8601})"

    def hours_rule
      if user.fixed_target?
        "This user has a fixed monthly target of #{fmt(user.monthly_target)}h, spread evenly over the month's weekdays " \
          "(this month #{fmt(user.daily_hours_for(today.beginning_of_month.next_weekday))}h per weekday). " \
          "Todos logged on the same day share that day's hours."
      else
        "This user has no monthly target: each logged weekday counts #{User::DAILY_HOURS}h, shared by that day's todos."
      end
    end

    # [label, what it means] for each holiday/leave kind.
    def day_kinds
      DayKind::DISPLAY.map { |kind| [ kind.label, kind.billable ? "billed as a normal working day" : "logged, but 0 hours and never billed" ] }
    end

    def month_end? = AssistantSuggestions.month_end?(today)
    def month_start? = AssistantSuggestions.month_start?(today)

    def paid_examples = DayKind::PAID_EXAMPLES.join(", ")
    def unpaid_examples = DayKind::UNPAID_EXAMPLES.join(", ")

    def fmt(hours) = hours.to_f.round(2)
  end
end
