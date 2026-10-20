class OneEntryPerDayAndPreciseHours < ActiveRecord::Migration[8.1]
  def up
    # 160h / 22 weekdays = 7.2727..., keep 4 decimals so a month's days still add up to ~160
    change_column :time_entries, :hours, :decimal, precision: 6, scale: 4, null: false, default: 0
    add_index :time_entries, %i[user_id log_date], unique: true
  end

  def down
    remove_index :time_entries, %i[user_id log_date]
    change_column :time_entries, :hours, :decimal, precision: 5, scale: 2, null: false, default: 0
  end
end
