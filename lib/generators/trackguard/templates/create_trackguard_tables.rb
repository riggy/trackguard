class CreateTrackguardTables < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :trackguard_visitors do |t|
      t.string   :ip
      t.string   :user_agent
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at,  null: false
      t.datetime :flagged_at
      t.string   :flag_reason
      t.string   :flagged_by
      t.timestamps
    end

    add_index :trackguard_visitors, :ip, unique: true

    create_table :trackguard_page_views do |t|
      t.string    :path,       null: false
      t.string    :user_agent
      t.string    :referer
      t.string    :session_id
      t.string    :trace_id
      t.string    :source
      t.references :visitor,   null: false, foreign_key: { to_table: :trackguard_visitors }
      t.datetime  :created_at, null: false
    end

    add_index :trackguard_page_views, :path
    add_index :trackguard_page_views, :created_at
    add_index :trackguard_page_views, :source

    create_table :trackguard_whitelisted_ips do |t|
      t.string   :ip,         null: false
      t.datetime :expires_at, null: false
      t.references :visitor,  foreign_key: { to_table: :trackguard_visitors }
      t.timestamps
    end

    add_index :trackguard_whitelisted_ips, :ip,         unique: true
    add_index :trackguard_whitelisted_ips, :expires_at

    create_table :trackguard_blocked_user_agents do |t|
      t.string :pattern, null: false
      t.timestamps
    end

    add_index :trackguard_blocked_user_agents, :pattern, unique: true
  end
end
