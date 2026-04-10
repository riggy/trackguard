require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('dummy/config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

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
    t.timestamps
  end

  add_index :trackguard_visitors, :ip, unique: true

  create_table :trackguard_page_views, force: :cascade do |t|
    t.string   :path,       null: false
    t.string   :user_agent
    t.string   :referer
    t.string   :session_id
    t.string   :trace_id
    t.string   :source
    t.bigint   :visitor_id, null: false
    t.datetime :created_at, null: false
  end

  add_index :trackguard_page_views, :path
  add_index :trackguard_page_views, :created_at
  add_index :trackguard_page_views, :source
  add_index :trackguard_page_views, :visitor_id
end

FactoryBot.definition_file_paths = [ File.expand_path("factories", __dir__) ]
FactoryBot.find_definitions

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  config.filter_rails_from_backtrace!
end
