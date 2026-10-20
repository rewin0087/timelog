class TimeEntriesController < ApplicationController
  before_action :set_entry, only: %i[edit update destroy]

  def index
    @entries = Current.user.time_entries.order(log_date: :desc, created_at: :desc).limit(200)
  end

  def new
    @entry = Current.user.time_entries.new(log_date: Date.current)
  end

  def create
    @entry = Current.user.time_entries.new(entry_params)
    if @entry.save
      redirect_to time_entries_path, notice: "Timelog created."
    else
      render :new, status: :unprocessable_entity
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
      render :edit, status: :unprocessable_entity
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
