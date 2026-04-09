class AddPageViewUuidToPageViews < ActiveRecord::Migration[8.1]
  def change
    add_column :page_views, :trace_id, :string
  end
end
