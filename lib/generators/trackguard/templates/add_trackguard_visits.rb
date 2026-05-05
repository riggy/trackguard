# frozen_string_literal: true

class AddTrackguardVisits < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    rename_table :trackguard_page_views, :trackguard_visits

    add_column :trackguard_visits, :type,         :string
    add_column :trackguard_visits, :block_reason, :string
    add_column :trackguard_visits, :http_method,  :string

    add_index :trackguard_visits, :type
    add_index :trackguard_visits, :block_reason

    execute "UPDATE trackguard_visits SET type = 'Trackguard::PageView'"
  end

  def down
    remove_index :trackguard_visits, :block_reason
    remove_index :trackguard_visits, :type

    remove_column :trackguard_visits, :http_method
    remove_column :trackguard_visits, :block_reason
    remove_column :trackguard_visits, :type

    rename_table :trackguard_visits, :trackguard_page_views
  end
end
