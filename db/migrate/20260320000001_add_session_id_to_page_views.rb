class AddSessionIdToPageViews < ActiveRecord::Migration[8.1]
  def change
    add_column :page_views, :session_id, :string
  end
end
