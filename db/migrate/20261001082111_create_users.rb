class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      # Contractor profile, used on invoices
      t.string :name, null: false
      t.text :address
      t.decimal :hourly_rate, precision: 12, scale: 2
      t.string :currency, null: false, default: "PHP"
      t.string :bank_account_name
      t.string :bank_account_number
      t.string :bank_name
      t.string :bank_swift

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
