require "rails/generators"
require "rails/generators/active_record"

module Trackguard
  class UpgradeGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def create_migration_files
      migration_template "create_trackguard_visitors.rb",           "db/migrate/create_trackguard_visitors.rb"
      migration_template "create_trackguard_visits.rb",             "db/migrate/create_trackguard_visits.rb"
      migration_template "create_trackguard_whitelisted_ips.rb",    "db/migrate/create_trackguard_whitelisted_ips.rb"
      migration_template "create_trackguard_blocked_user_agents.rb",
                         "db/migrate/create_trackguard_blocked_user_agents.rb"
      migration_template "create_trackguard_blocked_paths.rb", "db/migrate/create_trackguard_blocked_paths.rb"
    end

    def print_next_steps
      say "\nNext steps:", :green
      say "  1. rails db:migrate"
      say "  2. rails trackguard:seed_blocked_paths"
    end
  end
end
