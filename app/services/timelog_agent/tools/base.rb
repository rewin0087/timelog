class TimelogAgent
  module Tools
    # A tool the model can call, for one user on one day. Subclasses declare their name, description and
    # parameters with `tool`, and implement #call(args) (args: the model's arguments, string keys) returning
    # a Hash that is sent back to the model as JSON. A tool that produces a document also #attach-es it, so the
    # reply shows it with preview and download buttons (see ChatMessage#attachments).
    class Base
      class << self
        attr_reader :tool_name, :description, :properties, :required

        def tool(name, description:, properties: {}, required: [])
          @tool_name, @description, @properties, @required = name, description, properties, required
        end

        # The OpenAI-style function definition sent with each request.
        def definition
          { type: "function",
            function: { name: tool_name, description:, parameters: { type: "object", properties:, required: } } }
        end
      end

      def initialize(user, today: Date.current, attachments: [])
        @user = user
        @today = today
        @attachments = attachments
      end

      def call(args) = raise(NotImplementedError)

      private

      attr_reader :user, :today

      def invalid!(message) = raise(InvalidArguments, message)

      def attach(kind, **data) = @attachments << { "kind" => kind, **data.transform_keys(&:to_s) }

      # A month from "YYYY-MM", or the current month when blank.
      def month_arg(value) = value.present? ? Date.strptime(value.to_s, "%Y-%m") : today.beginning_of_month

      # Weekdays from `from` to `to` (never past today) with nothing logged.
      def unlogged_weekdays(from, to, logged_dates)
        (from..[ to, today ].min).select { |d| !d.on_weekend? && !logged_dates.include?(d) }
      end

      def hours(value) = value.to_f.round(2)
    end
  end
end
