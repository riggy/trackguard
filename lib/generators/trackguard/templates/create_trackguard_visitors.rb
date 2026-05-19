class CreateTrackguardVisitors < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :trackguard_visitors do |t|
      t.string   :ip
      t.string   :name
      t.string   :user_agent
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at,  null: false
      t.datetime :flagged_at
      t.string   :flag_reason
      t.string   :flagged_by
      t.timestamps
    end

    add_index :trackguard_visitors, :ip, unique: true
  end
end