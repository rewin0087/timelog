# Back-office accounts. Super admins only.
class Admin::AdministratorsController < Admin::BaseController
  before_action -> { require_permission!(:manage_admins) }
  before_action :set_administrator, only: %i[edit update destroy]

  def index
    @administrators = Administrator.order(super_admin: :desc, name: :asc)
  end

  def new
    @administrator = Administrator.new(access_level: "view")
  end

  def create
    @administrator = Administrator.new(administrator_params)
    if @administrator.save
      redirect_to admin_administrators_path, notice: "#{@administrator.name} can now sign in with #{@administrator.access_label.downcase}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    attrs = administrator_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?
    if @administrator.update(attrs)
      @administrator.admin_sessions.where.not(id: Current.admin_session.id).destroy_all if @administrator.saved_change_to_password_digest?
      redirect_to admin_administrators_path, notice: "#{@administrator.name} was updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @administrator == current_admin
      redirect_to admin_administrators_path, alert: "You can't delete your own account."
    elsif @administrator.destroy
      redirect_to admin_administrators_path, notice: "#{@administrator.name} was removed.", status: :see_other
    else
      redirect_to admin_administrators_path, alert: @administrator.errors.full_messages.to_sentence
    end
  end

  private
    def set_administrator = @administrator = Administrator.find(params[:id])
    def administrator_params = params.require(:administrator).permit(:name, :email_address, :password, :password_confirmation, :access_level)
end
