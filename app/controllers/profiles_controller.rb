class ProfilesController < ApplicationController
  PROFILE_FIELDS = %i[name address bill_to_name bill_to_address invoice_item hourly_rate currency bank_account_name bank_account_number bank_name
                      bank_swift invoice_due_day hours_mode monthly_hours].freeze

  def edit
    @user = @lock_user = Current.user
  end

  def update
    @user = Current.user
    @user.assign_attributes(params.require(:user).permit(*PROFILE_FIELDS))
    if @user.save(context: :invoice_details)
      recalculated = @user.saved_change_to_hours_mode? || @user.saved_change_to_monthly_hours?
      redirect_to root_path, notice: recalculated ? "Profile saved. Hours on your logs were recalculated." : "Profile saved."
    else
      @lock_user = User.find(@user.id)
      render :edit, status: :unprocessable_entity
    end
  end
end
