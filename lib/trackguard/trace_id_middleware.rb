# frozen_string_literal: true

module Trackguard
  class TraceIdMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["trackguard.trace_id"] = SecureRandom.uuid
      @app.call(env)
    end
  end
end
