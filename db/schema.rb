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

ActiveRecord::Schema[8.1].define(version: 2026_06_05_211000) do
  create_table "posts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.datetime "published_at"
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "tags"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_posts_on_slug", unique: true
    t.index ["status", "published_at"], name: "index_posts_on_status_and_published_at"
  end

  create_table "sections", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "heading"
    t.string "key", null: false
    t.string "page", default: "home", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.index ["key"], name: "index_sections_on_key", unique: true
    t.index ["page", "position"], name: "index_sections_on_page_and_position"
    t.index ["position"], name: "index_sections_on_position"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_site_settings_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
end
