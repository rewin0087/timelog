# Set up (first sign-in) or change the lock code and auto-lock period.
class LockSettingsController < ApplicationController
  skip_screen_lock
  before_action -> { block_request(lock_path) if Current.user.lock_configured? && Current.session.locked? }
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to edit_lock_settings_path, alert: "Too many attempts. Try again later." }

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    setup = !@user.lock_configured?
    attrs = params.require(:user).permit(:lock_pin, :lock_pin_confirmation, :auto_lock_minutes)
    attrs = attrs.except(:lock_pin, :lock_pin_confirmation) if attrs[:lock_pin].blank? && !setup

    if !setup && !verified_current_secret?
      @user.errors.add(:base, "Enter your current lock code or account password to make changes")
    elsif setup && attrs[:lock_pin].blank?
      @user.errors.add(:lock_pin, "can't be blank")
    end

    if @user.errors.none? && @user.update(attrs)
      Current.session.unlock!
      redirect_to (setup ? after_unlock_url : edit_profile_path),
        notice: setup ? "Lock screen is on. Lock it any time from the sidebar or with Ctrl+Shift+L." : "Lock screen settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    # A forgotten code can be reset with the account password.
    def verified_current_secret?
      secret = params[:current_secret].to_s
      secret.present? && (@user.authenticate_lock_pin(secret) || @user.authenticate_password(secret)).present?
    end
end
