# frozen_string_literal: true

require "net/http"
require "json"

module Trackguard
  module Adapters
    class Hub < Base
      CACHE_KEY = "trackguard/hub_rules"
      STALE_KEY = "trackguard/hub_rules/stale"
      ETAG_KEY  = "trackguard/hub_rules/etag"

      def validate!
        missing = []
        missing << "hub_api_key"    if Trackguard.hub_api_key.blank?
        missing << "hub_secret_key" if Trackguard.hub_secret_key.blank?
        return if missing.empty?

        raise Trackguard::ConfigurationError, <<~MSG.strip
          Trackguard Hub adapter is missing required credentials: #{missing.join(', ')}.

          Set them in your initializer:

              Trackguard.configure do |c|
                c.adapter        = :hub
                c.hub_api_key    = ENV["TRACKGUARD_API_KEY"]
                c.hub_secret_key = ENV["TRACKGUARD_SECRET_KEY"]
              end

          Sign up at https://trackguard.dev to create a project and generate credentials.

          To use local tracking instead (no external service needed):

              Trackguard.configure { |c| c.adapter = :local }
        MSG
      end

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
        Trackguard::Hub::SubmitBlockedRequestJob.perform_later(
          ip: ip, user_agent: user_agent, path: path, http_method: http_method, block_reason: block_reason
        )
      end

      protected

      def perform_track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:,
                                  tracking_layer:, http_method:, prefetch: false)
        return if prefetch

        Trackguard::Hub::SubmitPageViewJob.perform_later(
          path: path, ip: ip, user_agent: user_agent, referer: referer,
          session_id: session_id, trace_id: trace_id, source: source,
          tracking_layer: tracking_layer, http_method: http_method
        )
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
        uri = URI("#{Trackguard.hub_url}/api/backend/rules")
        response = execute_http(uri, build_request(uri))

        return Rails.cache.read(STALE_KEY) || {} if response.is_a?(Net::HTTPNotModified)

        raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        fresh = JSON.parse(response.body, symbolize_names: true)
        Rails.cache.write(ETAG_KEY, response["ETag"], expires_in: 24.hours) if response["ETag"]
        fresh
      end

      def build_request(uri)
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{Trackguard.hub_secret_key}"
        req["X-Api-Key"] = Trackguard.hub_api_key
        req["Accept"] = "application/json"
        etag = Rails.cache.read(ETAG_KEY)
        req["If-None-Match"] = etag if etag
        req
      end

      def execute_http(uri, request)
        opts = { use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5 }
        Net::HTTP.start(uri.hostname, uri.port, **opts) { |http| http.request(request) }
      end
    end
  end
end
