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

ActiveRecord::Schema[8.1].define(version: 2026_11_25_100003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "answer_chunks", force: :cascade do |t|
    t.bigint "answer_id", null: false
    t.bigint "chunk_id", null: false
    t.float "similarity", null: false
    t.integer "rank", null: false
    t.boolean "cited", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_id", "rank"], name: "index_answer_chunks_on_answer_id_and_rank", unique: true
    t.index ["answer_id"], name: "index_answer_chunks_on_answer_id"
    t.index ["chunk_id"], name: "index_answer_chunks_on_chunk_id"
  end

  create_table "answers", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_answers_on_question_id", unique: true
  end

  create_table "article_tags", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "tag_id"], name: "index_article_tags_on_article_id_and_tag_id", unique: true
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

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

  create_table "chunks", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.integer "position", null: false
    t.text "content", null: false
    t.integer "word_count", null: false
    t.vector "embedding", limit: 1536, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "position"], name: "index_chunks_on_article_id_and_position", unique: true
    t.index ["article_id"], name: "index_chunks_on_article_id"
    t.index ["embedding"], name: "index_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
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

  create_table "questions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "answer_chunks", "answers"
  add_foreign_key "answer_chunks", "chunks"
  add_foreign_key "answers", "questions"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
  add_foreign_key "articles", "users"
  add_foreign_key "chunks", "articles"
  add_foreign_key "questions", "users"
  add_foreign_key "tags", "users"
end
