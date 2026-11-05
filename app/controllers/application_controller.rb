class ApplicationController < ActionController::Base
  include Authentication
  include ScreenLock
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_theme

  private
    def current_theme
      Theme.resolve(session[:theme])
    end
end
