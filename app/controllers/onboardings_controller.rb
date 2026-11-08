# Two required steps after sign-up: invoice details, then the lock screen.
# ScreenLock sends every page here until both are done (User#onboarded?).
class OnboardingsController < ApplicationController
  STEPS = %w[invoice lock].freeze

  skip_screen_lock
  before_action :set_user
  before_action -> { block_request(lock_path) if @user.lock_configured? && Current.session.locked? }
  before_action -> { redirect_to after_unlock_url if @user.onboarded? }
  before_action :set_step
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to onboarding_path, alert: "Too many attempts. Try again later." }

  def show
  end

  def update
    @step == "invoice" ? save_invoice_details : save_lock_settings
  end

  private
    def set_user
      @user = Current.user
    end

    # The lock step only opens once the invoice details are complete.
    def set_step
      @step = params[:step].presence_in(STEPS) || (@user.invoice_details_complete? ? "lock" : "invoice")
      @step = "invoice" unless @user.invoice_details_complete?
    end

    def save_invoice_details
      @user.assign_attributes(params.require(:user).permit(*ProfilesController::ALL_FIELDS))
      if @user.save(context: :invoice_details)
        @user.onboarded? ? finish : redirect_to(onboarding_path(step: "lock"))
      else
        render :show, status: :unprocessable_entity
      end
    end

    def save_lock_settings
      attrs = params.require(:user).permit(:lock_pin, :lock_pin_confirmation, :auto_lock_minutes)
      @user.errors.add(:lock_pin, "can't be blank") if attrs[:lock_pin].blank?
      if @user.errors.none? && @user.update(attrs)
        finish
      else
        render :show, status: :unprocessable_entity
      end
    end

    def finish
      Current.session.unlock!
      redirect_to after_unlock_url, notice: "You're all set. Lock the screen any time from the sidebar or with Ctrl+Shift+L."
    end
end
