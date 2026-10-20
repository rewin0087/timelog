class AllowMultipleEntriesPerDay < ActiveRecord::Migration[8.1]
  def up
    remove_index :time_entries, %i[user_id log_date]
    add_index :time_entries, %i[user_id log_date]
  end

  def down
    remove_index :time_entries, %i[user_id log_date]
    add_index :time_entries, %i[user_id log_date], unique: true
  end
end
