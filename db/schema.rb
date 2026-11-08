# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_08_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_sessions", force: :cascade do |t|
    t.bigint "administrator_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["administrator_id"], name: "index_admin_sessions_on_administrator_id"
  end

  create_table "administrators", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "super_admin", default: false, null: false
    t.boolean "can_create", default: false, null: false
    t.boolean "can_edit", default: false, null: false
    t.datetime "last_signed_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_administrators_on_email_address", unique: true
  end

  create_table "daily_inspirations", force: :cascade do |t|
    t.date "day", null: false
    t.text "verse_text", null: false
    t.string "verse_reference", null: false
    t.text "verse_reflection"
    t.jsonb "questions", default: [], null: false
    t.string "source", default: "ai", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["day"], name: "index_daily_inspirations_on_day", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "number", null: false
    t.date "period", null: false
    t.date "invoice_date", null: false
    t.date "due_date", null: false
    t.decimal "hours", precision: 8, scale: 2, null: false
    t.decimal "rate", precision: 12, scale: 2, null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.index ["user_id", "number"], name: "index_invoices_on_user_id_and_number", unique: true
    t.index ["user_id", "period"], name: "index_invoices_on_user_id_and_period"
    t.index ["user_id", "period_start"], name: "index_invoices_on_user_id_and_period_start", unique: true
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "locked_at"
    t.datetime "last_active_at"
    t.integer "failed_unlock_attempts", default: 0, null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.date "log_date", null: false
    t.text "todo", null: false
    t.decimal "hours", precision: 6, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["log_date"], name: "index_time_entries_on_log_date"
    t.index ["user_id", "log_date"], name: "index_time_entries_on_user_id_and_log_date"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.text "address"
    t.decimal "hourly_rate", precision: 12, scale: 2
    t.string "currency", default: "PHP", null: false
    t.string "bank_account_name"
    t.string "bank_account_number"
    t.string "bank_name"
    t.string "bank_swift"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "invoice_due_day", default: 5, null: false
    t.string "lock_pin_digest"
    t.integer "auto_lock_minutes", default: 5, null: false
    t.string "hours_mode", default: "monthly", null: false
    t.decimal "monthly_hours", precision: 6, scale: 2
    t.string "bill_to_name"
    t.text "bill_to_address"
    t.string "invoice_item", default: "Consultancy Service", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "admin_sessions", "administrators"
  add_foreign_key "invoices", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_entries", "users"
end
