class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.hstore :settings

      t.timestamps null: false
    end
  end
end
