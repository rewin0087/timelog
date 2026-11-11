class TimelogAgent
  # Which saved messages are replayed to the model: the most recent LIMIT, starting on a user message
  # so a tool result is never sent without the assistant call that asked for it.
  class History
    LIMIT = 60

    def initialize(messages, limit: LIMIT)
      @messages = messages
      @limit = limit
    end

    def to_api = @messages.last(@limit).drop_while { |m| !m.user? }.map(&:to_api)
  end
end
