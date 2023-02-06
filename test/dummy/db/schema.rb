# frozen_string_literal: true

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
#
# The schema usually includes the version, for example ActiveRecord::Schema[7.0]
# It was manually removed from this file to allow testing with different Rails versions

ActiveRecord::Schema.define(version: 20_230_202_172_207) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index %w[record_type record_id name blob_id], name: "index_active_storage_attachments_uniqueness",
                                                    unique: true
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
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index %w[blob_id variation_digest], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "character_mushrooms", force: :cascade do |t|
    t.string "name"
    t.integer "level_id"
    t.datetime "collection_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level_id"], name: "index_character_mushrooms_on_level_id"
  end

  create_table "character_turtles", force: :cascade do |t|
    t.string "name"
    t.integer "level_id"
    t.string "type"
    t.date "birthday"
    t.text "history"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level_id"], name: "index_character_turtles_on_level_id"
  end

  create_table "levels", force: :cascade do |t|
    t.string "name"
    t.string "difficulty"
    t.boolean "unlocked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "weaponizable_weapons", force: :cascade do |t|
    t.string "weaponizable_type"
    t.integer "weaponizable_id"
    t.string "type"
    t.integer "power"
    t.float "precision"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index %w[weaponizable_type weaponizable_id], name: "index_weaponizable_weapons_on_weaponizable"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
