class CreateTrackguardVisits < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :trackguard_visits do |t|
      t.string    :type
      t.string    :path,         null: false
      t.string    :user_agent
      t.string    :referer
      t.string    :session_id
      t.string    :trace_id
      t.string    :source
      t.string    :block_reason
      t.string    :http_method
      t.references :visitor,     null: false, foreign_key: { to_table: :trackguard_visitors }
      t.datetime  :created_at,   null: false
    end

    add_index :trackguard_visits, :type
    add_index :trackguard_visits, :path
    add_index :trackguard_visits, :created_at
    add_index :trackguard_visits, :source
    add_index :trackguard_visits, :block_reason
  end
end