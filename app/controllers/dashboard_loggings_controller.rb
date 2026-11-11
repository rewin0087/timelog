# Saves what the dashboard's top card offers for logging (User::DASHBOARD_LOGGING).
class DashboardLoggingsController < ApplicationController
  def update
    if Current.user.update(dashboard_logging: params[:mode])
      redirect_to root_path, notice: "Dashboard now shows: #{User::DASHBOARD_LOGGING.fetch(Current.user.dashboard_logging)}."
    else
      redirect_to root_path, alert: "Pick one of the dashboard options."
    end
  end
end
