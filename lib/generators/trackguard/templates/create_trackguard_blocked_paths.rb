class CreateTrackguardBlockedPaths < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :trackguard_blocked_paths do |t|
      t.string :pattern, null: false
      t.timestamps
    end

    add_index :trackguard_blocked_paths, :pattern, unique: true
  end
end