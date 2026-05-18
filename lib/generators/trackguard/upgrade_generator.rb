require "rails/generators"
require "rails/generators/active_record"

module Trackguard
  class UpgradeGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def create_visits_migration_file
      migration_template "add_trackguard_visits.rb", "db/migrate/add_trackguard_visits.rb"
    end

    def create_visitor_name_migration_file
      migration_template "add_visitor_name.rb", "db/migrate/add_visitor_name.rb"
    end

    def create_blocked_paths_migration_file
      migration_template "add_trackguard_blocked_paths.rb", "db/migrate/add_trackguard_blocked_paths.rb"
    end

    def print_next_steps
      say "\nNext steps:", :green
      say "  1. rails db:migrate"
    end
  end
end
