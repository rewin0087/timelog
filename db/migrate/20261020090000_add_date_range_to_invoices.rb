class AddDateRangeToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :period_start, :date
    add_column :invoices, :period_end, :date
    execute <<~SQL
      UPDATE invoices
      SET period_start = period,
          period_end = (period + INTERVAL '1 month' - INTERVAL '1 day')::date
    SQL
    change_column_null :invoices, :period_start, false
    change_column_null :invoices, :period_end, false

    # A month can now hold several invoices (e.g. 1st–15th and 16th–end).
    remove_index :invoices, %i[user_id period]
    add_index :invoices, %i[user_id period]
    add_index :invoices, %i[user_id period_start], unique: true
  end

  def down
    remove_index :invoices, %i[user_id period_start]
    remove_index :invoices, %i[user_id period]
    add_index :invoices, %i[user_id period], unique: true
    remove_column :invoices, :period_end
    remove_column :invoices, :period_start
  end
end
