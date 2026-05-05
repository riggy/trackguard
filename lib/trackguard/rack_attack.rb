# frozen_string_literal: true

require "rack/attack"

module Trackguard
  module RackAttack
    def self.configure
      ::Rack::Attack.safelist("trackguard/allow local") do |req|
        [ "127.0.0.1", "::1" ].include?(req.ip)
      end

      ::Rack::Attack.safelist("trackguard/allow whitelisted ips") do |req|
        Trackguard::WhitelistedIp.whitelisted?(req.ip)
      end

      ::Rack::Attack.blocklist("trackguard/block known scanners") do |req|
        Trackguard::BlockedUserAgent.blocked?(req.user_agent)
      end

      ::Rack::Attack.blocklist("trackguard/flagged visitors") do |req|
        Trackguard::Visitor.flagged?(req.ip)
      end

      ::Rack::Attack.throttle(
        "trackguard/requests by ip",
        limit: Trackguard.throttle_limit,
        period: Trackguard.throttle_period, &:ip
      )

      subscribe_to_blocked_requests
    end

    def self.subscribe_to_blocked_requests
      @subscribe_to_blocked_requests ||= ActiveSupport::Notifications.subscribe("rack.attack") do |*, payload|
        req = payload[:request]
        next unless req.env["rack.attack.match_type"] == :blocklist

        Trackguard::TrackBlockedRequestJob.perform_later(
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
