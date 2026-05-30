# frozen_string_literal: true

require "net/http"
require "json"

module Trackguard
  module Hub
    class SubmitPageViewJob < ApplicationJob
      queue_as :default

      def perform(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, http_method:, **)
        uri  = URI("#{Trackguard.hub_url}/api/backend/page_views")
        body = {
          page_view: {
            path: path, referer: referer, session_id: session_id, trace_id: trace_id,
            source: source, http_method: http_method, ip: ip, user_agent: user_agent
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
            "[Trackguard::Hub::SubmitPageViewJob] Unexpected response #{response.code} for path=#{path}"
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[Trackguard::Hub::SubmitPageViewJob] Failed to submit page view: #{e.message}")
      end
    end
  end
end
