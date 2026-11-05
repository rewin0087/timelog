class ThemesController < ApplicationController
  def update
    session[:theme] = Theme.resolve(params[:theme])

    respond_to do |format|
      format.html { redirect_back_or_to root_path }
      format.json { head :no_content }
    end
  end
end
