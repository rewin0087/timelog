# Resolves report params into a date range and a human label.
#   period=month (default)  -> current month, or a specific month via `month=YYYY-MM`
#   period=previous_month   -> the month before the current one
#   period=days             -> last N days (`count`), ending today
#   period=weeks            -> last N weeks (`count`), ending today
#   period=custom           -> explicit `from` / `to` dates
class ReportRange
  PERIODS = %w[month previous_month days weeks custom].freeze

  attr_reader :from, :to, :label

  def initialize(params, today: Date.current)
    period = PERIODS.include?(params[:period]) ? params[:period] : "month"
    count = [[params[:count].to_i, 1].max, 366].min

    case period
    when "previous_month"
      set_month(today.prev_month.beginning_of_month)
    when "days"
      @to = today
      @from = today - (count - 1)
      @label = "Last #{count} day#{'s' if count > 1}"
    when "weeks"
      @to = today
      @from = today - (count * 7 - 1)
      @label = "Last #{count} week#{'s' if count > 1}"
    when "custom"
      @from = parse(params[:from]) || today.beginning_of_month
      @to = parse(params[:to]) || today
      @from, @to = @to, @from if @from > @to
      @label = "#{@from.strftime('%d %b %Y')} – #{@to.strftime('%d %b %Y')}"
    else
      set_month(parse_month(params[:month]) || today.beginning_of_month)
    end
  end

  def entries(user)
    user.time_entries.between(from, to).chronological
  end

  def filename
    "timelog_#{from.iso8601}_to_#{to.iso8601}.pdf"
  end

  private

  def set_month(date)
    @from = date.beginning_of_month
    @to = date.end_of_month
    @label = date.strftime("%B %Y")
  end

  def parse(str)
    Date.iso8601(str.to_s)
  rescue ArgumentError
    nil
  end

  def parse_month(str)
    Date.strptime(str.to_s, "%Y-%m")
  rescue ArgumentError
    nil
  end
end
