class TimelogAgent
  # The tools the model can call. Lists their definitions for the request, and runs one by name with the
  # model's JSON arguments. Problems come back as { error: "..." } so the model can explain them or retry,
  # rather than failing the whole reply. Documents the tools produce are collected in #attachments.
  class Toolbox
    TOOLS = [
      Tools::GetAccount, Tools::LogTodo, Tools::ListTimeEntries, Tools::MonthSummary, Tools::ListInvoices,
      Tools::PrepareInvoice, Tools::ExportReport
    ].freeze

    def self.definitions = TOOLS.map(&:definition)

    attr_reader :attachments

    def initialize(user, today: Date.current)
      @attachments = []
      @tools = TOOLS.to_h { |tool| [ tool.tool_name, tool.new(user, today:, attachments: @attachments) ] }
    end

    def call(name, raw_arguments)
      tool = @tools[name] or return { error: "Unknown tool #{name}" }
      tool.call(parse(raw_arguments))
    rescue JSON::ParserError
      { error: "The arguments were not valid JSON" }
    rescue Tools::InvalidArguments, Date::Error => e
      { error: e.message }
    end

    private

    def parse(raw_arguments)
      args = raw_arguments.present? ? JSON.parse(raw_arguments) : {}
      args.is_a?(Hash) ? args : raise(Tools::InvalidArguments, "The arguments must be a JSON object")
    end
  end
end
