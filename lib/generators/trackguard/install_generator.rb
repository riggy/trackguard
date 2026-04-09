require 'rails/generators'
require 'rails/generators/active_record'

module Trackguard
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('templates', __dir__)

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def create_migration_file
      migration_template 'create_trackguard_tables.rb', 'db/migrate/create_trackguard_tables.rb'
    end
  end
end
