# Gates every signed-in request behind the lock screen:
#   no lock code yet   -> lock-code setup page
#   session is locked  -> lock screen
#   otherwise          -> record activity (feeds server-side auto-lock)
module ScreenLock
  extend ActiveSupport::Concern

  included do
    before_action :enforce_screen_lock
    after_action :prevent_caching_private_pages
    helper_method :app_unlocked?
  end

  class_methods do
    def skip_screen_lock(**options)
      skip_before_action :enforce_screen_lock, **options
    end
  end

  private
    def enforce_screen_lock
      return unless Current.session

      if !Current.user.lock_configured?
        block_request(edit_lock_settings_path)
      elsif Current.session.locked?
        Current.session.lock! # make an idle auto-lock stick
        block_request(lock_path)
      else
        Current.session.touch_activity!
      end
    end

    def block_request(path)
      if request.format.html?
        session[:return_to_after_unlock] = request.url if request.get? && !request.xhr?
        redirect_to path
      else
        head :locked
      end
    end

    def app_unlocked?
      Current.session.present? && Current.user.lock_configured? && !Current.session.locked?
    end

    def after_unlock_url
      session.delete(:return_to_after_unlock) || root_url
    end

    # Signed-in pages must not be served from the browser's back/forward cache after the screen locks.
    def prevent_caching_private_pages
      response.headers["Cache-Control"] = "no-store" if Current.session && response.media_type == "text/html"
    end
end
