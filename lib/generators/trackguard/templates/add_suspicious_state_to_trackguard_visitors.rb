class AddSuspiciousStateToTrackguardVisitors < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :trackguard_visitors, :suspicious_state, :string, null: false, default: "normal"
    add_column :trackguard_visitors, :suspicious_since_at, :datetime

    reversible do |dir|
      dir.up do
        execute "UPDATE trackguard_visitors SET suspicious_state = 'blocked' WHERE flagged_at IS NOT NULL"
      end
    end
  end
end
