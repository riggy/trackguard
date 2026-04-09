class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.string :path, null: false
      t.string :ip
      t.string :user_agent
      t.string :referer
      t.datetime :created_at, null: false
    end
    add_index :page_views, :created_at
    add_index :page_views, :path
  end
end
