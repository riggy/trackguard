# frozen_string_literal: true

module Trackguard
  class Engine < ::Rails::Engine
    isolate_namespace Trackguard

    config.to_prepare do
      ActionController::Base.helper Trackguard::ApplicationHelper
    end

    initializer "trackguard.assets" do |app|
      app.config.assets.precompile += %w[trackguard/admin.css] if app.config.respond_to?(:assets)
    end

    initializer "trackguard.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    initializer "trackguard.trace_id_middleware" do |app|
      app.middleware.use Trackguard::TraceIdMiddleware
    end

    config.after_initialize do
      Trackguard::RackAttack.configure
    end
  end
end
