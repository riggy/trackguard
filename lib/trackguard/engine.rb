module Trackguard
  class Engine < ::Rails::Engine
    isolate_namespace Trackguard

    initializer "trackguard.helpers" do
      ActiveSupport::on_load(:action_controller) do
        helper Trackguard::ApplicationHelper
      end
    end

    initializer "trackguard.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end
  end
end
