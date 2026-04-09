class AddFlaggedByToVisitors < ActiveRecord::Migration[8.1]
  def change
    add_column :visitors, :flagged_by, :string
  end
end
