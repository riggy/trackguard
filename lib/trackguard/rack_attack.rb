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
    end
  end
end
