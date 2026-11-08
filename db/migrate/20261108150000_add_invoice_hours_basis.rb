# How an invoice's hours are worked out (Invoice::HOURS_BASES):
#   logged - the billable hours logged in the period (the default, and always used without a monthly target)
#   target - the fixed monthly target prorated by weekdays, skipping time logs
# users.invoice_hours_basis is the account default; each invoice stores the basis it was generated with.
class AddInvoiceHoursBasis < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :invoice_hours_basis, :string, null: false, default: "logged"
    add_column :invoices, :hours_basis, :string, null: false, default: "logged"
    # Invoices generated so far for fixed-target users billed the target.
    execute <<~SQL
      UPDATE invoices SET hours_basis = 'target'
      FROM users WHERE users.id = invoices.user_id AND users.hours_mode = 'monthly'
    SQL
  end

  def down
    remove_column :invoices, :hours_basis
    remove_column :users, :invoice_hours_basis
  end
end
