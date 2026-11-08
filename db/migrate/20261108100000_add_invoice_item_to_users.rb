# The invoice line item used to be fixed to "Consultancy Service" in InvoicePdf.
class AddInvoiceItemToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :invoice_item, :string, null: false, default: "Consultancy Service"
  end
end
