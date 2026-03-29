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

ActiveRecord::Schema[8.0].define(version: 2026_03_29_065239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.string "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chat_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "chat_session_id", null: false
    t.string "role", null: false
    t.text "content"
    t.jsonb "citations", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
  end

  create_table "chat_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_id"
    t.uuid "project_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_chat_sessions_on_meeting_id"
    t.index ["project_id", "meeting_id"], name: "index_chat_sessions_on_project_id_and_meeting_id"
    t.index ["project_id"], name: "index_chat_sessions_on_project_id"
  end

  create_table "extracted_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_id", null: false
    t.uuid "transcript_chunk_id"
    t.string "item_type", null: false
    t.text "description", null: false
    t.string "owner"
    t.date "due_date"
    t.float "confidence_score"
    t.text "source_quote"
    t.integer "source_timestamp"
    t.string "status", default: "open", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "item_type"], name: "index_extracted_items_on_meeting_id_and_item_type"
    t.index ["meeting_id", "status"], name: "index_extracted_items_on_meeting_id_and_status"
    t.index ["meeting_id"], name: "index_extracted_items_on_meeting_id"
    t.index ["transcript_chunk_id"], name: "index_extracted_items_on_transcript_chunk_id"
  end

  create_table "meetings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "title", null: false
    t.date "meeting_date"
    t.integer "duration_seconds"
    t.integer "speaker_count"
    t.integer "word_count"
    t.float "overall_sentiment_score"
    t.jsonb "sentiment_data", default: {}
    t.string "status", default: "pending", null: false
    t.text "processing_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "meeting_date"], name: "index_meetings_on_project_id_and_meeting_date"
    t.index ["project_id"], name: "index_meetings_on_project_id"
    t.index ["status"], name: "index_meetings_on_status"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "slug", null: false
    t.integer "meetings_count", default: 0, null: false
    t.integer "total_action_items_count", default: 0, null: false
    t.float "overall_sentiment_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "speakers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "name", null: false
    t.string "display_name"
    t.string "role"
    t.string "email"
    t.float "average_sentiment"
    t.integer "meetings_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_speakers_on_project_id_and_name"
    t.index ["project_id"], name: "index_speakers_on_project_id"
  end

  create_table "transcript_chunks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "transcript_id", null: false
    t.uuid "meeting_id", null: false
    t.text "content", null: false
    t.string "speaker_name"
    t.integer "start_time"
    t.integer "end_time"
    t.integer "chunk_index"
    t.vector "embedding", limit: 768
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_transcript_chunks_on_embedding_hnsw", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["meeting_id", "chunk_index"], name: "index_transcript_chunks_on_meeting_id_and_chunk_index"
    t.index ["meeting_id"], name: "index_transcript_chunks_on_meeting_id"
    t.index ["transcript_id"], name: "index_transcript_chunks_on_transcript_id"
  end

  create_table "transcripts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_id", null: false
    t.string "file_name"
    t.string "file_format"
    t.text "raw_content"
    t.jsonb "parsed_segments", default: []
    t.integer "total_speakers"
    t.string "language_code", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "detected_meeting_date"
    t.index ["meeting_id"], name: "index_transcripts_on_meeting_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "meetings"
  add_foreign_key "chat_sessions", "projects"
  add_foreign_key "extracted_items", "meetings"
  add_foreign_key "extracted_items", "transcript_chunks"
  add_foreign_key "meetings", "projects"
  add_foreign_key "projects", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "speakers", "projects"
  add_foreign_key "transcript_chunks", "meetings"
  add_foreign_key "transcript_chunks", "transcripts"
  add_foreign_key "transcripts", "meetings"
end
