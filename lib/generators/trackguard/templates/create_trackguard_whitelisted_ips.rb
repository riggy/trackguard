class CreateTrackguardWhitelistedIps < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :trackguard_whitelisted_ips do |t|
      t.string   :ip,         null: false
      t.datetime :expires_at, null: false
      t.references :visitor,  foreign_key: { to_table: :trackguard_visitors }
      t.timestamps
    end

    add_index :trackguard_whitelisted_ips, :ip,         unique: true
    add_index :trackguard_whitelisted_ips, :expires_at
  end
end