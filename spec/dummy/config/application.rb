require_relative 'boot'

require 'active_record/railtie'
require 'active_model/railtie'
require 'action_controller/railtie'
require 'active_job/railtie'

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.load_defaults 8.1

    config.eager_load = false
    config.active_job.queue_adapter = :test

    config.logger = Logger.new(nil)
    config.log_level = :fatal
  end
end
