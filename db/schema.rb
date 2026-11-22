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

ActiveRecord::Schema[8.1].define(version: 2026_11_22_010234) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "articles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "url", null: false
    t.integer "status", default: 0, null: false
    t.string "failure_reason"
    t.string "title"
    t.text "text"
    t.integer "word_count"
    t.boolean "tagging_failed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "summary_tldr"
    t.jsonb "summary_key_points", default: [], null: false
    t.index ["user_id", "url"], name: "index_articles_on_user_id_and_url", unique: true
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "llm_calls", force: :cascade do |t|
    t.integer "purpose", null: false
    t.string "model", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "thinking_tokens"
    t.integer "latency_ms"
    t.integer "status", null: false
    t.text "error_message"
    t.string "subject_type"
    t.bigint "subject_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subject_type", "subject_id"], name: "index_llm_calls_on_subject"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "articles", "users"
end
