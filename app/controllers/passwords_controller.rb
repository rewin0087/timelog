# Changes the account password from the profile page. Other signed-in devices are signed out.
class PasswordsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to edit_profile_path(anchor: "password"), alert: "Too many attempts. Try again later." }

  def update
    @password_user = Current.user
    attrs = params.require(:user).permit(:password, :password_confirmation)

    if !@password_user.authenticate_password(params[:current_password].to_s)
      @password_user.errors.add(:base, "Current password is incorrect")
    elsif attrs[:password].blank?
      @password_user.errors.add(:password, "can't be blank")
    end

    if @password_user.errors.none? && @password_user.update(attrs)
      @password_user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to edit_profile_path(anchor: "password"), notice: "Password updated. Any other devices were signed out."
    else
      @user = @invoice_user = @lock_user = User.find(@password_user.id)
      render "profiles/edit", status: :unprocessable_content
    end
  end
end
