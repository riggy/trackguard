class AddSourceToPageViews < ActiveRecord::Migration[8.1]
  def change
    add_column :page_views, :source, :string
    add_index :page_views, :source
  end
end
