# frozen_string_literal: true

require "net/http"
require "json"

module Trackguard
  module Hub
    class SubmitBlockedRequestJob < ApplicationJob
      queue_as :default

      def perform(ip:, user_agent:, path:, http_method:, block_reason:)
        uri  = URI("#{Trackguard.hub_url}/api/backend/blocked_requests")
        body = {
          blocked_request: {
            ip: ip, user_agent: user_agent, path: path,
            http_method: http_method, block_reason: block_reason
          }
        }.to_json

        req                  = Net::HTTP::Post.new(uri)
        req["X-Api-Key"]     = Trackguard.hub_api_key
        req["Authorization"] = "Bearer #{Trackguard.hub_secret_key}"
        req["Content-Type"]  = "application/json"
        req.body             = body

        opts     = { use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5 }
        response = Net::HTTP.start(uri.hostname, uri.port, **opts) { |http| http.request(req) }

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn(
            "[Trackguard::Hub::SubmitBlockedRequestJob] Unexpected response #{response.code} for path=#{path}"
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[Trackguard::Hub::SubmitBlockedRequestJob] Failed to submit blocked request: #{e.message}")
      end
    end
  end
end
