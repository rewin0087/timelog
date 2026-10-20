class AddInvoiceDueDayToUsers < ActiveRecord::Migration[8.1]
  def change
    # Day of the month following the invoice date that invoices fall due.
    add_column :users, :invoice_due_day, :integer, default: 5, null: false
  end
end
