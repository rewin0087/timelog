class AddHoursSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    # "monthly": a fixed monthly target (monthly_hours, blank = 160) spread over the month's weekdays.
    # "daily":   no monthly target; every logged weekday counts DAILY_HOURS (8h).
    add_column :users, :hours_mode, :string, null: false, default: "monthly"
    add_column :users, :monthly_hours, :decimal, precision: 6, scale: 2
  end
end
