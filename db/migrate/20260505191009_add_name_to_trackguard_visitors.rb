class AddNameToTrackguardVisitors < ActiveRecord::Migration[8.0]
  def change
    add_column :trackguard_visitors, :name, :string
  end
end
