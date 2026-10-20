class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.date :log_date, null: false
      t.text :todo, null: false
      t.decimal :hours, precision: 5, scale: 2, null: false, default: 0

      t.timestamps
    end
    add_index :time_entries, :log_date
  end
end
