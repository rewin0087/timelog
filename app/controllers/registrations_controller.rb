class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action -> { redirect_to root_path if authenticated? }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:name, :email_address, :password, :password_confirmation))
    if @user.save
      start_new_session_for @user
      redirect_to edit_profile_path, notice: "Welcome! Complete your invoice details below."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
