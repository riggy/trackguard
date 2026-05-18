# frozen_string_literal: true

require "rack/attack"

module Trackguard
  module RackAttack
    # rubocop:disable Metrics/MethodLength
    def self.configure
      adapter = Trackguard.adapter

      ::Rack::Attack.safelist("trackguard/allow local") do |req|
        [ "127.0.0.1", "::1" ].include?(req.ip)
      end

      ::Rack::Attack.safelist("trackguard/allow whitelisted ips") do |req|
        adapter.whitelisted_ip?(req.ip)
      end

      ::Rack::Attack.blocklist("trackguard/block known scanners") do |req|
        adapter.blocked_user_agent?(req.user_agent)
      end

      ::Rack::Attack.blocklist("trackguard/block known paths") do |req|
        adapter.blocked_path?(req.path)
      end

      ::Rack::Attack.blocklist("trackguard/flagged visitors") do |req|
        adapter.flagged_visitor?(req.ip)
      end

      ::Rack::Attack.throttle(
        "trackguard/requests by ip",
        limit: Trackguard.throttle_limit,
        period: Trackguard.throttle_period, &:ip
      )

      subscribe_to_blocked_requests(adapter)
    end
    # rubocop:enable Metrics/MethodLength

    def self.subscribe_to_blocked_requests(adapter)
      @subscribe_to_blocked_requests ||= ActiveSupport::Notifications.subscribe("rack.attack") do |*, payload|
        req = payload[:request]
        next unless req.env["rack.attack.match_type"] == :blocklist

        adapter.track_blocked_request(
          ip: req.ip,
          user_agent: req.user_agent.to_s,
          path: req.path,
          http_method: req.request_method,
          block_reason: req.env["rack.attack.matched"].to_s
        )
      rescue StandardError
        # never let tracking errors surface into the middleware response
      end
    end
    private_class_method :subscribe_to_blocked_requests
  end
end
