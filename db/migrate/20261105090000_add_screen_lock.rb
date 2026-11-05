class AddScreenLock < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :lock_pin_digest, :string
    add_column :users, :auto_lock_minutes, :integer, default: 5, null: false

    add_column :sessions, :locked_at, :datetime
    add_column :sessions, :last_active_at, :datetime
    add_column :sessions, :failed_unlock_attempts, :integer, default: 0, null: false
  end
end
