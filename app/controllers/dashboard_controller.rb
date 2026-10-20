class DashboardController < ApplicationController
  def show
    today = Date.current
    @view = params[:view] == "month" ? "month" : "week"

    if @view == "month"
      month = (Date.strptime(params[:month].to_s, "%Y-%m") rescue today).beginning_of_month
      @from, @to = month, month.end_of_month
      @title = month.strftime("%B %Y")
      @prev_month = month.prev_month.strftime("%Y-%m")
      @next_month = month.next_month.strftime("%Y-%m")
    else
      @from, @to = today.beginning_of_week, today.end_of_week
      @title = "This week (#{@from.strftime('%d %b')} – #{@to.strftime('%d %b')})"
    end

    @entries = Current.user.time_entries.between(@from, @to).chronological
    @total_hours = @entries.sum(:hours)
    @by_day = @entries.group_by(&:log_date)
    @new_entry = Current.user.time_entries.new(log_date: today)
  end
end
