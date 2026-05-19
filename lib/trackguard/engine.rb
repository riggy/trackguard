# frozen_string_literal: true

module Trackguard
  class Engine < ::Rails::Engine
    isolate_namespace Trackguard

    initializer "trackguard.helpers" do
      ActiveSupport.on_load(:action_controller) do
        helper ApplicationHelper
        helper DashboardHelper
      end
    end

    initializer "trackguard.assets" do |app|
      app.config.assets.precompile += %w[trackguard/admin.css] if app.config.respond_to?(:assets)
    end

    initializer "trackguard.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    config.after_initialize do
      Trackguard::RackAttack.configure
    end
  end
end
