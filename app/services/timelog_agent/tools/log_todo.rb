class TimelogAgent
  module Tools
    # Logs one todo as a time entry, then reports how that day's hours are now shared.
    class LogTodo < Base
      MAX_DAYS_AWAY = 366

      tool "log_todo",
           description: "Log one todo (a task the user worked on) as a time entry. Hours are worked out automatically: " \
                        "the day's hours are shared by all todos logged that day. Holiday or leave wording " \
                        "(e.g. 'Public holiday', 'Sick leave', 'Absent') marks the day as that kind.",
           properties: {
             todo: { type: "string", description: "What the user worked on, in their words. Keep line breaks for multi-line todos." },
             date: { type: "string", description: "The day to log it on, YYYY-MM-DD. Omit for today." }
           },
           required: %w[todo]

      def call(args)
        todo = args["todo"].to_s.strip
        invalid!("The todo text is empty") if todo.empty?
        day = args["date"].present? ? Date.iso8601(args["date"]) : today
        invalid!("#{day.iso8601} is more than a year from today; check the date") if (day - today).abs > MAX_DAYS_AWAY

        entry = user.time_entries.create!(log_date: day, todo:)
        {
          logged: { id: entry.id, date: day.iso8601, weekday: day.strftime("%A"), todo: entry.todo, kind: entry.day_kind&.label },
          day: day_summary(day),
          note: ("Weekends count 0 hours." if day.on_weekend?)
        }.compact
      end

      private

      def day_summary(day)
        todos = user.time_entries.where(log_date: day).chronological
        { todos: todos.map { |e| { todo: e.todo, hours: hours(e.hours) } }, hours: hours(todos.sum(:hours)) }
      end
    end
  end
end
