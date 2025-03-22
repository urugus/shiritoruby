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

ActiveRecord::Schema[8.0].define(version: 2025_03_18_122700) do
  create_table "game_words", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "word_id", null: false
    t.integer "turn", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_game_words_on_game_id"
    t.index ["word_id"], name: "index_game_words_on_word_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "player_name", null: false
    t.integer "score", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duration_seconds"
  end

  create_table "words", force: :cascade do |t|
    t.string "word", null: false
    t.string "normalized_word", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_word"], name: "index_words_on_normalized_word", unique: true
    t.index ["word"], name: "index_words_on_word", unique: true
  end

  add_foreign_key "game_words", "games"
  add_foreign_key "game_words", "words"
end
