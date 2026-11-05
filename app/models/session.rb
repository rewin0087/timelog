class Session < ApplicationRecord
  MAX_UNLOCK_ATTEMPTS = 5

  belongs_to :user

  # Locked when locked by hand, or when nothing has happened for the user's auto-lock period.
  # Auto-lock is decided here on the server, so closing the tab or killing JavaScript doesn't bypass it.
  def locked?
    locked_at.present? || idle_too_long?
  end

  def lock!
    update!(locked_at: Time.current) unless locked_at
  end

  def unlock!
    update!(locked_at: nil, last_active_at: Time.current, failed_unlock_attempts: 0)
  end

  def touch_activity!
    update_column(:last_active_at, Time.current) if last_active_at.nil? || last_active_at < 15.seconds.ago
  end

  # Returns true once the attempt limit is reached.
  def record_failed_unlock!
    increment!(:failed_unlock_attempts)
    failed_unlock_attempts >= MAX_UNLOCK_ATTEMPTS
  end

  def unlock_attempts_left = MAX_UNLOCK_ATTEMPTS - failed_unlock_attempts

  private
    def idle_too_long?
      user.auto_lock? && last_active_at.present? && last_active_at < user.auto_lock_minutes.minutes.ago
    end
end
