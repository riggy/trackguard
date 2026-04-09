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
  end
end
