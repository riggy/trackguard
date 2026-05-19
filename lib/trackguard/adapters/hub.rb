# frozen_string_literal: true

require "net/http"
require "json"

module Trackguard
  module Adapters
    class Hub < Base
      CACHE_KEY = "trackguard/hub_rules"
      STALE_KEY = "trackguard/hub_rules/stale"
      ETAG_KEY  = "trackguard/hub_rules/etag"

      def blocked_user_agent?(user_agent)
        rules.fetch(:blocked_user_agents, []).any? do |p|
          user_agent.to_s.downcase.include?(p.downcase)
        end
      end

      def blocked_path?(path)
        rules.fetch(:blocked_paths, []).any? do |p|
          path.to_s.downcase.include?(p.downcase)
        end
      end

      def whitelisted_ip?(ip)
        rules.fetch(:whitelisted_ips, []).include?(ip)
      end

      def flagged_visitor?(ip)
        rules.fetch(:flagged_ips, []).include?(ip)
      end

      def track_blocked_request(ip:, user_agent:, path:, http_method:, block_reason:)
        # placeholder: hub adapter does not persist blocked requests locally
      end

      protected

      def perform_track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, initial:,
                                  http_method:)
        # placeholder: hub tracking not yet implemented
      end

      private

      def rules
        Rails.cache.fetch(CACHE_KEY, expires_in: Trackguard.hub_rules_ttl, race_condition_ttl: 10) do
          fresh = fetch_rules_from_hub
          Rails.cache.write(STALE_KEY, fresh, expires_in: 24.hours)
          fresh
        end
      rescue StandardError => e
        Rails.logger.warn("[Trackguard::Adapters::Hub] Failed to fetch rules: #{e.message}")
        Rails.cache.read(STALE_KEY) || {}
      end

      def fetch_rules_from_hub
        uri = URI("#{Trackguard.hub_url}/api/rules")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{Trackguard.hub_secret_key}"
        request["Accept"] = "application/json"

        etag = Rails.cache.read(ETAG_KEY)
        request["If-None-Match"] = etag if etag

        response = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 3,
          read_timeout: 5
        ) do |http|
          http.request(request)
        end

        return Rails.cache.read(STALE_KEY) || {} if response.is_a?(Net::HTTPNotModified)

        raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        fresh = JSON.parse(response.body, symbolize_names: true)
        Rails.cache.write(ETAG_KEY, response["ETag"], expires_in: 24.hours) if response["ETag"]
        fresh
      end
    end
  end
end
