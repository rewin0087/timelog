# Changes the lock code and auto-lock period from the profile page.
# The first lock code is set during onboarding (OnboardingsController).
class LockSettingsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to edit_profile_path, alert: "Too many attempts. Try again later." }

  def update
    @lock_user = Current.user
    attrs = params.require(:user).permit(:lock_pin, :lock_pin_confirmation, :auto_lock_minutes)
    attrs = attrs.except(:lock_pin, :lock_pin_confirmation) if attrs[:lock_pin].blank?

    unless verified_current_secret?
      @lock_user.errors.add(:base, "Enter your current lock code or account password to change lock settings")
    end

    if @lock_user.errors.none? && @lock_user.update(attrs)
      redirect_to edit_profile_path(anchor: "lock-screen"), notice: "Lock screen settings saved."
    else
      @user = @invoice_user = User.find(@lock_user.id)
      @password_user = User.find(@lock_user.id)
      render "profiles/edit", status: :unprocessable_entity
    end
  end

  private
    # A forgotten code can be reset with the account password.
    def verified_current_secret?
      secret = params[:current_secret].to_s
      secret.present? && (@lock_user.authenticate_lock_pin(secret) || @lock_user.authenticate_password(secret)).present?
    end
end
