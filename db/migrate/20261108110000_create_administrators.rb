# Back-office accounts, kept apart from app users. Everyone can view; create/edit are granted per account,
# and super admins have all access (delete, reveal sensitive data, manage administrators).
class CreateAdministrators < ActiveRecord::Migration[8.1]
  def change
    create_table :administrators do |t|
      t.string :name, null: false
      t.string :email_address, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.boolean :super_admin, null: false, default: false
      t.boolean :can_create, null: false, default: false
      t.boolean :can_edit, null: false, default: false
      t.datetime :last_signed_in_at
      t.timestamps
    end

    create_table :admin_sessions do |t|
      t.references :administrator, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
