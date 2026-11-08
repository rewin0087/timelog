# Light or dark admin skin, kept in the session (separate from the app user's skin).
class Admin::ThemesController < Admin::BaseController
  def update
    session[:admin_theme] = params[:theme].presence_in(ADMIN_THEMES.keys) || DEFAULT_ADMIN_THEME
    respond_to do |format|
      format.html { redirect_back_or_to admin_root_path }
      format.json { head :no_content }
    end
  end
end
