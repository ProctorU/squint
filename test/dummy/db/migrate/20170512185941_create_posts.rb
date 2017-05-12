class CreatePosts < ActiveRecord::Migration
  def change
    enable_extension "hstore"
    create_table :posts do |t|
      t.string :title
      t.string :body
      t.jsonb :request_info
      t.hstore :properties

      t.timestamps null: false
    end
  end
end
