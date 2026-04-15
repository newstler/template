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

ActiveRecord::Schema[8.2].define(version: 2026_04_15_015226) do
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

  create_table "articles", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "team_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["team_id"], name: "index_articles_on_team_id"
    t.index ["user_id"], name: "index_articles_on_user_id"
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

  create_table "conversation_messages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.json "body_translations", default: {}, null: false
    t.text "content"
    t.string "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "flag_reason"
    t.datetime "flagged_at"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["conversation_id"], name: "index_conversation_messages_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_messages_on_user_id"
  end

  create_table "conversation_participants", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_notified_at"
    t.datetime "last_read_at"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversation_participants_on_conversation_id_and_user_id", unique: true
    t.index ["conversation_id"], name: "index_conversation_participants_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_participants_on_user_id"
  end

  create_table "conversations", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "subject_id"
    t.string "subject_type"
    t.string "team_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["subject_type", "subject_id"], name: "index_conversations_on_subject"
    t.index ["team_id"], name: "index_conversations_on_team_id"
  end

  create_table "languages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.string "native_name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
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

  create_table "mobility_string_translations", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "locale", null: false
    t.string "translatable_id", null: false
    t.string "translatable_type", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_string_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_string_translations_on_keys", unique: true
    t.index ["translatable_type", "key", "value", "locale"], name: "index_mobility_string_translations_on_query_keys"
  end

  create_table "mobility_text_translations", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "locale", null: false
    t.string "translatable_id", null: false
    t.string "translatable_type", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_text_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_text_translations_on_keys", unique: true
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

  create_table "noticed_events", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.json "params"
    t.string "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.datetime "read_at"
    t.string "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "provider_credentials", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["provider", "key"], name: "index_provider_credentials_on_provider_and_key", unique: true
  end

  create_table "rails_error_dashboard_applications", force: :cascade do |t|
    t.datetime "created_at"
    t.text "description"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_rails_error_dashboard_applications_on_name", unique: true
  end

  create_table "rails_error_dashboard_cascade_patterns", force: :cascade do |t|
    t.float "avg_delay_seconds"
    t.float "cascade_probability"
    t.bigint "child_error_id", null: false
    t.datetime "created_at", null: false
    t.integer "frequency", default: 1, null: false
    t.datetime "last_detected_at"
    t.bigint "parent_error_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cascade_probability"], name: "index_cascade_patterns_on_probability"
    t.index ["child_error_id"], name: "index_cascade_patterns_on_child"
    t.index ["parent_error_id", "child_error_id"], name: "index_cascade_patterns_on_parent_and_child", unique: true
    t.index ["parent_error_id"], name: "index_cascade_patterns_on_parent"
  end

  create_table "rails_error_dashboard_diagnostic_dumps", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.text "dump_data", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_rails_error_dashboard_diagnostic_dumps_on_application_id"
    t.index ["captured_at"], name: "index_diagnostic_dumps_on_captured_at"
  end

  create_table "rails_error_dashboard_error_baselines", force: :cascade do |t|
    t.string "baseline_type", null: false
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "error_type", null: false
    t.float "mean"
    t.float "percentile_95"
    t.float "percentile_99"
    t.datetime "period_end", null: false
    t.datetime "period_start", null: false
    t.string "platform", null: false
    t.integer "sample_size", default: 0, null: false
    t.float "std_dev"
    t.datetime "updated_at", null: false
    t.index ["error_type", "platform", "baseline_type", "period_start"], name: "index_error_baselines_on_type_platform_baseline_period"
    t.index ["error_type", "platform"], name: "index_error_baselines_on_error_type_and_platform"
    t.index ["period_end"], name: "index_error_baselines_on_period_end"
  end

  create_table "rails_error_dashboard_error_comments", force: :cascade do |t|
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "updated_at", null: false
    t.index ["error_log_id", "created_at"], name: "index_error_comments_on_error_and_time"
    t.index ["error_log_id"], name: "index_rails_error_dashboard_error_comments_on_error_log_id"
  end

  create_table "rails_error_dashboard_error_logs", force: :cascade do |t|
    t.string "action_name"
    t.string "app_version"
    t.bigint "application_id", null: false
    t.datetime "assigned_at"
    t.string "assigned_to"
    t.text "backtrace"
    t.string "backtrace_signature"
    t.text "breadcrumbs"
    t.string "content_type", limit: 100
    t.string "controller_name"
    t.datetime "created_at", null: false
    t.text "environment_info"
    t.string "error_hash"
    t.string "error_type", null: false
    t.text "exception_cause"
    t.integer "external_issue_number"
    t.string "external_issue_provider", limit: 20
    t.string "external_issue_url"
    t.datetime "first_seen_at"
    t.string "git_sha"
    t.string "hostname", limit: 255
    t.string "http_method", limit: 10
    t.text "instance_variables"
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.text "local_variables"
    t.text "message", null: false
    t.boolean "muted", default: false, null: false
    t.datetime "muted_at"
    t.string "muted_by"
    t.string "muted_reason"
    t.datetime "occurred_at", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.string "platform"
    t.integer "priority_level", default: 0
    t.integer "priority_score"
    t.datetime "reopened_at"
    t.integer "request_duration_ms"
    t.text "request_params"
    t.text "request_url"
    t.text "resolution_comment"
    t.string "resolution_reference"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.string "resolved_by_name"
    t.float "similarity_score"
    t.datetime "snoozed_until"
    t.string "status", default: "new"
    t.text "system_health"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.integer "user_id"
    t.index ["app_version", "resolved", "occurred_at"], name: "index_error_logs_on_version_resolution_time"
    t.index ["app_version"], name: "index_rails_error_dashboard_error_logs_on_app_version"
    t.index ["application_id", "occurred_at"], name: "index_error_logs_on_app_occurred"
    t.index ["application_id", "resolved"], name: "index_error_logs_on_app_resolved"
    t.index ["application_id"], name: "index_rails_error_dashboard_error_logs_on_application_id"
    t.index ["assigned_to", "status", "occurred_at"], name: "index_error_logs_on_assignment_workflow"
    t.index ["backtrace_signature"], name: "index_rails_error_dashboard_error_logs_on_backtrace_signature"
    t.index ["controller_name", "action_name", "error_hash"], name: "index_error_logs_on_controller_action_hash"
    t.index ["error_hash", "resolved", "occurred_at"], name: "index_error_logs_on_hash_resolved_occurred"
    t.index ["error_hash"], name: "index_rails_error_dashboard_error_logs_on_error_hash"
    t.index ["error_type", "occurred_at"], name: "index_error_logs_on_error_type_and_occurred_at"
    t.index ["error_type"], name: "index_rails_error_dashboard_error_logs_on_error_type"
    t.index ["first_seen_at"], name: "index_rails_error_dashboard_error_logs_on_first_seen_at"
    t.index ["git_sha"], name: "index_rails_error_dashboard_error_logs_on_git_sha"
    t.index ["last_seen_at"], name: "index_rails_error_dashboard_error_logs_on_last_seen_at"
    t.index ["muted"], name: "index_rails_error_dashboard_error_logs_on_muted"
    t.index ["occurred_at"], name: "index_rails_error_dashboard_error_logs_on_occurred_at"
    t.index ["occurrence_count"], name: "index_rails_error_dashboard_error_logs_on_occurrence_count"
    t.index ["platform", "occurred_at"], name: "index_error_logs_on_platform_and_occurred_at"
    t.index ["platform", "status", "occurred_at"], name: "index_error_logs_on_platform_status_time"
    t.index ["platform"], name: "index_rails_error_dashboard_error_logs_on_platform"
    t.index ["priority_level", "resolved", "occurred_at"], name: "index_error_logs_on_priority_resolution"
    t.index ["priority_score"], name: "index_rails_error_dashboard_error_logs_on_priority_score"
    t.index ["resolved", "occurred_at"], name: "index_error_logs_on_resolved_and_occurred_at"
    t.index ["resolved"], name: "index_rails_error_dashboard_error_logs_on_resolved"
    t.index ["similarity_score"], name: "index_rails_error_dashboard_error_logs_on_similarity_score"
    t.index ["user_id"], name: "index_rails_error_dashboard_error_logs_on_user_id"
  end

  create_table "rails_error_dashboard_error_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "occurred_at", null: false
    t.string "request_id"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["error_log_id"], name: "index_error_occurrences_on_error_log"
    t.index ["occurred_at", "error_log_id"], name: "index_error_occurrences_on_time_and_error"
    t.index ["request_id"], name: "index_error_occurrences_on_request"
    t.index ["user_id"], name: "index_error_occurrences_on_user"
  end

  create_table "rails_error_dashboard_swallowed_exceptions", force: :cascade do |t|
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.string "exception_class", limit: 250, null: false
    t.datetime "last_seen_at"
    t.datetime "period_hour", null: false
    t.integer "raise_count", default: 0, null: false
    t.string "raise_location", limit: 250, null: false
    t.integer "rescue_count", default: 0, null: false
    t.string "rescue_location", limit: 250
    t.datetime "updated_at", null: false
    t.index ["application_id", "period_hour"], name: "index_swallowed_exceptions_on_app_and_hour"
    t.index ["exception_class", "period_hour"], name: "index_swallowed_exceptions_on_class_and_hour"
    t.index ["exception_class", "raise_location", "rescue_location", "period_hour", "application_id"], name: "index_swallowed_exceptions_upsert_key", unique: true
    t.index ["period_hour"], name: "index_swallowed_exceptions_on_period_hour"
  end

  create_table "searchable_things", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "tags"
    t.datetime "updated_at", null: false
  end

  create_table "settings", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currencylayer_api_key"
    t.string "default_country_code"
    t.string "default_currency", default: "USD"
    t.string "default_model"
    t.string "embedding_model", default: "text-embedding-3-small"
    t.string "litestream_replica_access_key"
    t.string "litestream_replica_bucket"
    t.string "litestream_replica_key_id"
    t.string "mail_from"
    t.string "moderation_model"
    t.boolean "public_chats", default: true, null: false
    t.integer "rrf_k", default: 60
    t.string "search_tokenizer", default: "porter unicode61 remove_diacritics 2"
    t.string "smtp_address"
    t.string "smtp_password"
    t.string "smtp_username"
    t.string "stripe_publishable_key"
    t.string "stripe_secret_key"
    t.string "stripe_webhook_secret"
    t.string "translation_model"
    t.integer "trial_days", default: 30
    t.datetime "updated_at", null: false
  end

  create_table "team_languages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "language_id", null: false
    t.string "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_team_languages_on_language_id"
    t.index ["team_id", "language_id"], name: "index_team_languages_on_team_id_and_language_id", unique: true
    t.index ["team_id"], name: "index_team_languages_on_team_id"
  end

  create_table "teams", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "api_key", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.string "country_code"
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.string "default_currency", default: "USD", null: false
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
    t.string "locale"
    t.string "name"
    t.json "notification_preferences", default: {}, null: false
    t.string "preferred_currency"
    t.string "residence_country_code"
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "teams"
  add_foreign_key "articles", "users"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "teams"
  add_foreign_key "chats", "users"
  add_foreign_key "conversation_messages", "conversations"
  add_foreign_key "conversation_messages", "users"
  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "users"
  add_foreign_key "conversations", "teams"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "noticed_notifications", "noticed_events", column: "event_id"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "child_error_id"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "parent_error_id"
  add_foreign_key "rails_error_dashboard_diagnostic_dumps", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_comments", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "rails_error_dashboard_error_logs", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_occurrences", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "team_languages", "languages"
  add_foreign_key "team_languages", "teams"
  add_foreign_key "tool_calls", "messages"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "searchable_things_fts", "fts5", ["id UNINDEXED", "name", "description", "tags", "tokenize='porter unicode61 remove_diacritics 2'"]
end
