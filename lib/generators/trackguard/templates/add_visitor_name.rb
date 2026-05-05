# frozen_string_literal: true

class AddVisitorName < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :trackguard_visitors, :name, :string
  end
end
