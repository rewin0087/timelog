class ProfilesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(profile_params)
      redirect_to root_path, notice: "Profile saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :address, :hourly_rate, :currency, :bank_account_name,
                                 :bank_account_number, :bank_name, :bank_swift, :invoice_due_day)
  end
end
