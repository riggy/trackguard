module Trackguard
  class Engine < ::Rails::Engine
    initializer "trackguard.migrations" do |app|
      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path
      end
    end

    initializer "trackguard.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end
  end
end
