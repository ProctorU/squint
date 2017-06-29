# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170512185941) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "posts", force: :cascade do |t|
    t.string   "title"
    t.string   "body"
    t.jsonb    "request_info"
    t.hstore   "properties"
    t.jsonb    "storext_jsonb_attributes"
    t.hstore   "storext_hstore_attributes"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "posts", ["properties"], name: "index_posts_on_properties", using: :gin
  add_index "posts", ["request_info"], name: "index_posts_on_request_info", using: :gin
  add_index "posts", ["storext_hstore_attributes"], name: "index_posts_on_storext_hstore_attributes", using: :gin
  add_index "posts", ["storext_jsonb_attributes"], name: "index_posts_on_storext_jsonb_attributes", using: :gin

end
