# The profile page has separate forms (profile, invoice details, lock screen, password); each saves on its own.
class ProfilesController < ApplicationController
  PROFILE_FIELDS = %i[name address hours_mode monthly_hours].freeze
  INVOICE_FIELDS = %i[bill_to_name bill_to_address invoice_item hourly_rate currency invoice_due_day
                      bank_account_name bank_account_number bank_name bank_swift].freeze
  # Onboarding asks for both at once.
  ALL_FIELDS = (PROFILE_FIELDS + INVOICE_FIELDS).freeze

  def edit
    @user = @invoice_user = @lock_user = Current.user
    @password_user = User.find(@user.id)
  end

  def update
    invoice = params[:section] == "invoice"
    user = Current.user
    user.assign_attributes(params.require(:user).permit(*(invoice ? INVOICE_FIELDS : PROFILE_FIELDS)))

    if user.save(context: :invoice_details)
      redirect_to root_path, notice: update_notice(user, invoice)
    else
      # Only the form that was submitted shows the errors and the values typed into it.
      @user, @invoice_user = invoice ? [ User.find(user.id), user ] : [ user, User.find(user.id) ]
      @lock_user = @password_user = User.find(user.id)
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def update_notice(user, invoice)
      return "Invoice details saved." if invoice
      recalculated = user.saved_change_to_hours_mode? || user.saved_change_to_monthly_hours?
      recalculated ? "Profile saved. Hours on your logs were recalculated." : "Profile saved."
    end
end
