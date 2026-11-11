class AddDashboardLoggingToUsers < ActiveRecord::Migration[8.1]
  def change
    # What the dashboard's top card offers for logging: both | todo | assistant (see User::DASHBOARD_LOGGING).
    add_column :users, :dashboard_logging, :string, null: false, default: "both"
  end
end
