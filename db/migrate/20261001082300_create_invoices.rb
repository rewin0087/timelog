class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :number, null: false
      t.date :period, null: false          # first day of the invoiced month
      t.date :invoice_date, null: false    # end of the invoiced month
      t.date :due_date, null: false        # 5th of the following month
      t.decimal :hours, precision: 8, scale: 2, null: false
      t.decimal :rate, precision: 12, scale: 2, null: false
      t.string :currency, null: false

      t.timestamps
    end
    add_index :invoices, %i[user_id period], unique: true
    add_index :invoices, %i[user_id number], unique: true
  end
end
