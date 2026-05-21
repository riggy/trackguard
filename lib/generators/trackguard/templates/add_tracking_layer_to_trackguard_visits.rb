class AddTrackingLayerToTrackguardVisits < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :trackguard_visits, :tracking_layer, :string
  end
end
