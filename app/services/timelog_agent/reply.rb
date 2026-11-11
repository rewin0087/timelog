class TimelogAgent
  # A finished reply from the model: the text shown to the user and its follow-up suggestions, which the
  # model appends as `<suggestions>["...", "..."]</suggestions>` (see system_prompt.md.erb).
  class Reply < Data.define(:text, :suggestions)
    OPEN = "<suggestions>"
    CLOSE = "</suggestions>"
    PATTERN = %r{#{OPEN}(.*?)#{CLOSE}}m
    MAX_SUGGESTIONS = 3
    EMPTY_TEXT = "Done."

    def self.parse(content)
      content = content.to_s
      new(text: content.gsub(PATTERN, "").strip.presence || EMPTY_TEXT, suggestions: suggestions_in(content[PATTERN, 1]))
    end

    # Up to MAX_SUGGESTIONS non-blank strings from the JSON list; anything malformed is dropped.
    def self.suggestions_in(json)
      Array(json ? JSON.parse(json) : []).grep(String).map(&:squish).reject(&:empty?).first(MAX_SUGGESTIONS)
    rescue JSON::ParserError
      []
    end
    private_class_method :suggestions_in
  end
end
