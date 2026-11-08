class LocksController < ApplicationController
  skip_screen_lock only: %i[show create destroy]
  rate_limit to: 10, within: 1.minute, only: :destroy, with: -> { redirect_to lock_path, alert: "Too many attempts. Wait a minute and try again." }

  # The lock screen
  def show
    return redirect_to onboarding_path unless Current.user.lock_configured?
    redirect_to after_unlock_url unless Current.session.locked?
  end

  # Lock now (sidebar button, keyboard shortcut, idle timer)
  def create
    Current.session.lock!
    respond_to do |format|
      format.html { redirect_to lock_path }
      format.json { head :no_content }
    end
  end

  # Unlock with the lock code
  def destroy
    return redirect_to after_unlock_url unless Current.session.locked?

    if Current.user.authenticate_lock_pin(params[:pin].to_s)
      Current.session.unlock!
      redirect_to after_unlock_url
    elsif Current.session.record_failed_unlock!
      terminate_session
      redirect_to new_session_path, alert: "Too many wrong codes, so you've been signed out. Sign in with your password."
    else
      left = Current.session.unlock_attempts_left
      flash.now[:alert] = "Wrong code. #{left} #{"attempt".pluralize(left)} left before you're signed out."
      render :show, status: :unprocessable_entity
    end
  end

  # Activity ping from the idle timer; ScreenLock answers 423 instead if the session is already locked.
  def heartbeat
    head :no_content
  end
end
