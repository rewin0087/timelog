# Users: list and search, an overview per user (charts), and their details. Bank details are masked;
# blank bank fields on the edit form keep the stored values, so nobody has to see them to save the form.
class Admin::UsersController < Admin::BaseController
  PER_PAGE = 25
  DETAIL_FIELDS = %i[name email_address address bill_to_name bill_to_address invoice_item hourly_rate currency tax_rate
                     report_design report_color invoice_design invoice_color
                     invoice_due_day hours_mode monthly_hours auto_lock_minutes].freeze
  BANK_FIELDS = %i[bank_account_name bank_account_number bank_name bank_swift].freeze

  before_action :set_user, except: %i[index new create]
  before_action -> { require_permission!(:create) }, only: %i[new create]
  before_action -> { require_permission!(:edit) }, only: %i[update reset_lock sign_out_everywhere]
  before_action -> { require_permission!(:destroy) }, only: :destroy

  def index
    scope = User.order(created_at: :desc)
    if (@q = params[:q].to_s.strip).present?
      scope = scope.where("name ILIKE :q OR email_address ILIKE :q", q: "%#{User.sanitize_sql_like(@q)}%")
    end
    @total = scope.count
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @pages)
    @users = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @per_user = AdminStats.new.per_user(@users.map(&:id))
  end

  def show
    stats = TimeStats.new(@user)
    @months = stats.months(Date.current.prev_month(11), Date.current)
    @activity = stats.activity(18)
    @by_weekday = stats.entries_by_weekday
    @top_tasks = stats.top_tasks
    @totals = stats.totals
    @missed = stats.missed_weekdays
    @invoices = @user.invoices.includes(:items).order(period_start: :desc).limit(5)
    @invoiced = @user.invoices.includes(:items).group_by(&:currency).transform_values { |list| list.sum(&:amount) }
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:name, :email_address, :password, :password_confirmation, *DETAIL_FIELDS, *BANK_FIELDS))
    if @user.save
      redirect_to admin_user_path(@user), notice: "#{@user.name} was created. They finish onboarding (missing details and lock code) when they sign in."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = params.require(:user).permit(*DETAIL_FIELDS, *BANK_FIELDS, :password, :password_confirmation)
    attrs = attrs.reject { |key, value| key.to_sym.in?(BANK_FIELDS) && value.blank? }
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?
    if @user.update(attrs)
      redirect_to edit_admin_user_path(@user), notice: "#{@user.name}'s details were saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "#{@user.name} and all their timelogs and invoices were deleted.", status: :see_other
  end

  # Clears the lock code: the user sets a new one (onboarding) on their next request.
  def reset_lock
    @user.update_column(:lock_pin_digest, nil)
    redirect_to edit_admin_user_path(@user), notice: "Lock code reset. #{@user.name} will choose a new one next time."
  end

  def sign_out_everywhere
    count = @user.sessions.destroy_all.size
    redirect_to edit_admin_user_path(@user), notice: "Signed #{@user.name} out of #{ActionController::Base.helpers.pluralize(count, 'session')}.", status: :see_other
  end

  private
    def set_user
      @user = User.find(params[:id])
    end
end
