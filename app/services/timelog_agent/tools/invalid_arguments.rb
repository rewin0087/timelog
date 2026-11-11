class TimelogAgent
  module Tools
    # Raised by a tool when the model's arguments can't be used; Toolbox returns the message to the model.
    class InvalidArguments < ArgumentError; end
  end
end
