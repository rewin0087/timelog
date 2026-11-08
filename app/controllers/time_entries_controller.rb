class TimeEntriesController < ApplicationController
  PER_PAGE = 200
  before_action :set_entry, only: %i[edit update destroy]

  def index
    scope = Current.user.time_entries.order(log_date: :desc, created_at: :desc, id: :desc)
    @total = scope.count
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @pages)
    @entries = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    return unless @page == 1 # charts and stats only on the first page

    stats = TimeStats.new(Current.user)
    @months = stats.months(Date.current.prev_month(11), Date.current)
    @activity = stats.activity(18)
    @by_weekday = stats.entries_by_weekday
    @top_tasks = stats.top_tasks
    @totals = stats.totals
  end

  def new
    @entry = Current.user.time_entries.new(log_date: Date.current)
  end

  def create
    @entry = Current.user.time_entries.new(entry_params)
    if @entry.save
      redirect_to time_entries_path, notice: "Timelog created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Quick add from the dashboard: always logged against today's date.
  def create_today
    @entry = Current.user.time_entries.new(entry_params.merge(log_date: Date.current))
    if @entry.save
      redirect_to root_path, notice: "Logged for #{Date.current.strftime('%d %b %Y')}."
    else
      redirect_to root_path, alert: @entry.errors.full_messages.to_sentence
    end
  end

  def edit; end

  def update
    if @entry.update(entry_params)
      redirect_to time_entries_path, notice: "Timelog updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @entry.destroy
    redirect_to time_entries_path, notice: "Timelog deleted.", status: :see_other
  end

  private

  def set_entry
    @entry = Current.user.time_entries.find(params[:id])
  end

  def entry_params
    params.require(:time_entry).permit(:log_date, :todo)
  end
end
