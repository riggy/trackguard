require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("dummy/config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

# Set up the test database schema
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :trackguard_visitors, force: :cascade do |t|
    t.string   :ip
    t.string   :user_agent
    t.datetime :first_seen_at, null: false
    t.datetime :last_seen_at,  null: false
    t.datetime :flagged_at
    t.string   :flag_reason
    t.string   :flagged_by
    t.string   :name
    t.string   :suspicious_state, null: false, default: "normal"
    t.datetime :suspicious_since_at
    t.timestamps
  end

  add_index :trackguard_visitors, :ip, unique: true

  create_table :trackguard_visits, force: :cascade do |t|
    t.string   :type
    t.string   :path, null: false
    t.string   :user_agent
    t.string   :referer
    t.string   :session_id
    t.string   :trace_id
    t.string   :source
    t.string   :block_reason
    t.string   :http_method
    t.string   :tracking_layer
    t.bigint   :visitor_id, null: false
    t.datetime :created_at, null: false
  end

  add_index :trackguard_visits, :type
  add_index :trackguard_visits, :path
  add_index :trackguard_visits, :created_at
  add_index :trackguard_visits, :source
  add_index :trackguard_visits, :block_reason
  add_index :trackguard_visits, :visitor_id

  create_table :trackguard_whitelisted_ips, force: :cascade do |t|
    t.string   :ip,         null: false
    t.datetime :expires_at, null: false
    t.bigint   :visitor_id
    t.timestamps
  end

  add_index :trackguard_whitelisted_ips, :ip, unique: true
  add_index :trackguard_whitelisted_ips, :expires_at
  add_index :trackguard_whitelisted_ips, :visitor_id

  create_table :trackguard_blocked_user_agents, force: :cascade do |t|
    t.string :pattern, null: false
    t.timestamps
  end

  add_index :trackguard_blocked_user_agents, :pattern, unique: true

  create_table :trackguard_blocked_paths, force: :cascade do |t|
    t.string :pattern, null: false
    t.timestamps
  end

  add_index :trackguard_blocked_paths, :pattern, unique: true
end

FactoryBot.definition_file_paths = [ File.expand_path("factories", __dir__) ]
FactoryBot.find_definitions

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  config.filter_rails_from_backtrace!
end
