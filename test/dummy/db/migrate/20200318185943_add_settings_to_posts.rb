class AddSettingsToPosts < ActiveRecord::Migration
  def change
    change_table :posts do |t|
      t.jsonb :settings
    end
  end
end
