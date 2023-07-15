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

ActiveRecord::Schema[7.0].define(version: 2023_07_15_091640) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.string "key", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "boards", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "favorited_at"
    t.string "icon"
    t.string "color_theme"
    t.bigint "user_id", null: false
    t.jsonb "board_options", default: {}, null: false
    t.index ["user_id"], name: "index_boards_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.jsonb "field_values", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "board_id", null: false
    t.bigint "user_id", null: false
    t.index ["board_id"], name: "index_cards_on_board_id"
    t.index ["user_id"], name: "index_cards_on_user_id"
  end

  create_table "columns", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "board_id", null: false
    t.jsonb "sort_order", default: {}, null: false
    t.jsonb "card_inclusion_conditions", default: [], null: false
    t.integer "display_order"
    t.jsonb "card_grouping", default: {}, null: false
    t.jsonb "summary", default: {}, null: false
    t.bigint "user_id", null: false
    t.index ["board_id"], name: "index_columns_on_board_id"
    t.index ["user_id"], name: "index_columns_on_user_id"
  end

  create_table "elements", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_in_summary", default: false, null: false
    t.integer "data_type"
    t.integer "element_type", null: false
    t.boolean "read_only", default: false, null: false
    t.integer "display_order"
    t.bigint "board_id", null: false
    t.jsonb "element_options", default: {}, null: false
    t.integer "initial_value"
    t.jsonb "show_conditions", default: [], null: false
    t.bigint "user_id", null: false
    t.index ["board_id"], name: "index_elements_on_board_id"
    t.index ["user_id"], name: "index_elements_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ios_share_board_id"
    t.boolean "allow_emails", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["ios_share_board_id"], name: "index_users_on_ios_share_board_id"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "boards", "users"
  add_foreign_key "cards", "boards"
  add_foreign_key "cards", "users"
  add_foreign_key "columns", "boards"
  add_foreign_key "columns", "users"
  add_foreign_key "elements", "boards"
  add_foreign_key "elements", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "users", "boards", column: "ios_share_board_id"
end
