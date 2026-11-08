# A user's timelogs, month by month. Hours are split automatically per day (TimeEntry), as in the app.
class Admin::TimeEntriesController < Admin::BaseController
  before_action :set_user
  before_action :set_entry, only: %i[edit update destroy]
  before_action -> { require_permission!(:create) }, only: :create
  before_action -> { require_permission!(:edit) }, only: %i[edit update]
  before_action -> { require_permission!(:destroy) }, only: :destroy

  def index
    @month = (Date.strptime(params[:month].to_s, "%Y-%m") rescue Date.current).beginning_of_month
    @entries = @user.time_entries.between(@month, @month.end_of_month).chronological
    @entry = @user.time_entries.new(log_date: Date.current.clamp(@month, @month.end_of_month))
  end

  # Timesheet PDF for any report period (same periods and layout as the user's Export report page).
  def export
    range = ReportRange.new(params)
    send_data TimelogPdf.new(range, @user, style: PdfStyle.from(:report, params, @user)).render, filename: "#{@user.name.parameterize}_#{range.filename}", type: "application/pdf",
              disposition: params[:inline].present? ? "inline" : "attachment"
  end

  def create
    @entry = @user.time_entries.new(entry_params)
    if @entry.save
      redirect_to month_path(@entry.log_date), notice: "Timelog added for #{@entry.log_date.strftime('%d %b %Y')}."
    else
      redirect_to admin_user_time_entries_path(@user), alert: @entry.errors.full_messages.to_sentence
    end
  end

  def edit; end

  def update
    if @entry.update(entry_params)
      redirect_to month_path(@entry.log_date), notice: "Timelog updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @entry.destroy
    redirect_to month_path(@entry.log_date), notice: "Timelog deleted.", status: :see_other
  end

  private
    def set_user = @user = User.find(params[:user_id])
    def set_entry = @entry = @user.time_entries.find(params[:id])
    def entry_params = params.require(:time_entry).permit(:log_date, :todo)
    def month_path(date) = admin_user_time_entries_path(@user, month: date.strftime("%Y-%m"))
end
