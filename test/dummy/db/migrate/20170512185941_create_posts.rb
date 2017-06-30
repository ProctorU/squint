class CreatePosts < ActiveRecord::Migration
  def change
    enable_extension "hstore"
    create_table :posts do |t|
      t.string :title
      t.string :body
      t.jsonb :request_info
      t.hstore :properties
      t.jsonb :storext_jsonb_attributes
      t.hstore :storext_hstore_attributes

      t.timestamps null: false
      t.index :request_info, using: 'GIN'
      t.index :properties, using: 'GIN'
      t.index :storext_jsonb_attributes, using: 'GIN'
      t.index :storext_hstore_attributes, using: 'GIN'
    end
  end
end
