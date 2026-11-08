# The invoice "Bill to" block used to be fixed in InvoicePdf; existing users keep that address.
class AddBillToToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :bill_to_name, :string
    add_column :users, :bill_to_address, :text
    execute <<~SQL
      UPDATE users SET bill_to_name = 'Avvoka Limited',
                       bill_to_address = E'124 City Road\\nEC1V 2NX London\\nUnited Kingdom'
    SQL
  end

  def down
    remove_column :users, :bill_to_name
    remove_column :users, :bill_to_address
  end
end
