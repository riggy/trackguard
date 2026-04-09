require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('dummy/config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Run any pending migrations before the suite
ActiveRecord::Migration.verbose = false
ActiveRecord::MigrationContext.new(
  Rails.application.paths['db/migrate'].expanded
).migrate

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  config.filter_rails_from_backtrace!
end
