# Optional extra charges on an invoice (reimbursements, allowances...) and a tax rate.
# users.tax_rate is the default for new invoices; each invoice stores the rate it was generated with.
class AddInvoiceItemsAndTax < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1
      t.decimal :rate, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_column :invoices, :tax_rate, :decimal, precision: 5, scale: 2, null: false, default: 0
    add_column :users, :tax_rate, :decimal, precision: 5, scale: 2, null: false, default: 0
  end
end
