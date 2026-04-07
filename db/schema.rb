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

ActiveRecord::Schema[8.0].define(version: 2026_04_07_132000) do
  create_table "congregations", force: :cascade do |t|
    t.string "code", null: false
    t.string "old_code"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_congregations_on_code", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.integer "order_id", null: false
    t.string "entry_number"
    t.string "donor_name"
    t.integer "quantity", default: 0, null: false
    t.integer "amount", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wish"
    t.index ["order_id", "position"], name: "index_order_items_on_order_id_and_position", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "page_number", null: false
    t.string "form_type", null: false
    t.boolean "paid", default: false, null: false
    t.string "contact_name"
    t.string "phone"
    t.integer "user_id", null: false
    t.integer "congregation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["congregation_id", "page_number"], name: "index_orders_on_congregation_id_and_page_number"
    t.index ["congregation_id"], name: "index_orders_on_congregation_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "congregations"
  add_foreign_key "orders", "users"
end
