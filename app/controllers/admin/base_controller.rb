# Back office. Separate from the app: its own accounts (Administrator), cookie, layout, and no screen lock.
# Every signed-in administrator can view; actions that change data call `require_permission!`.
class Admin::BaseController < ActionController::Base
  # Admin skins: light or dark, mapped to app skins (see app/models/theme.rb).
  ADMIN_THEMES = { "dark" => "midnight", "light" => "violet" }.freeze
  DEFAULT_ADMIN_THEME = "dark"

  allow_browser versions: :modern
  layout "admin"

  before_action :require_admin
  after_action -> { response.headers["Cache-Control"] = "no-store" }
  helper_method :current_admin, :can?, :admin_theme

  private
    def current_admin = Current.administrator
    def admin_theme = session[:admin_theme].presence_in(ADMIN_THEMES.keys) || DEFAULT_ADMIN_THEME
    def can?(action) = current_admin&.can?(action)

    def require_admin
      Current.admin_session ||= AdminSession.find_by(id: cookies.signed[:admin_session_id]) if cookies.signed[:admin_session_id]
      redirect_to new_admin_session_path unless Current.admin_session
    end

    def require_permission!(action)
      return if can?(action)
      redirect_back fallback_location: admin_root_path, alert: "Your access level (#{current_admin.access_label}) doesn't allow that."
    end
end
