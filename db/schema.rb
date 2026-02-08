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

ActiveRecord::Schema[8.2].define(version: 2026_02_08_121032) do
  create_table "active_storage_attachments", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "chats", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "messages_count", default: 0, null: false
    t.string "model_id"
    t.string "team_id"
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
    t.index ["team_id"], name: "index_chats_on_team_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "memberships", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "invited_by_id"
    t.string "role", default: "member", null: false
    t.string "team_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["invited_by_id"], name: "index_memberships_on_invited_by_id"
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.string "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.string "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.string "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "chats_count", default: 0, null: false
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "provider_credentials", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["provider", "key"], name: "index_provider_credentials_on_provider_and_key", unique: true
  end

  create_table "settings", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "litestream_replica_access_key"
    t.string "litestream_replica_bucket"
    t.string "litestream_replica_key_id"
    t.boolean "public_chats", default: true, null: false
    t.string "smtp_address"
    t.string "smtp_password"
    t.string "smtp_username"
    t.string "stripe_publishable_key"
    t.string "stripe_secret_key"
    t.string "stripe_webhook_secret"
    t.integer "trial_days", default: 30
    t.datetime "updated_at", null: false
  end

  create_table "teams", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "api_key", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_teams_on_api_key", unique: true
    t.index ["slug"], name: "index_teams_on_slug", unique: true
    t.index ["stripe_customer_id"], name: "index_teams_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_teams_on_stripe_subscription_id", unique: true
  end

  create_table "tool_calls", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.string "name", null: false
    t.string "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "users", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "teams"
  add_foreign_key "chats", "users"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "tool_calls", "messages"
end
