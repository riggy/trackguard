# frozen_string_literal: true

module Trackguard
  module Adapters
    class Base
      def validate! = nil

      def blocked_user_agent?(user_agent) = raise NotImplementedError, "#{self.class}#blocked_user_agent?"
      def blocked_path?(path)             = raise NotImplementedError, "#{self.class}#blocked_path?"
      def whitelisted_ip?(ip)             = raise NotImplementedError, "#{self.class}#whitelisted_ip?"
      def flagged_visitor?(ip)            = raise NotImplementedError, "#{self.class}#flagged_visitor?"

      def track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, tracking_layer:,
                          http_method:, prefetch: false)
        return if blocked_user_agent?(user_agent)
        return if blocked_path?(path)
        return if path.blank? || path.start_with?(Trackguard.admin_path)

        perform_track_page_view(
          path: path, ip: ip, user_agent: user_agent, referer: referer,
          session_id: session_id, trace_id: trace_id, source: source,
          tracking_layer: tracking_layer, http_method: http_method, prefetch: prefetch
        )
      end

      def track_blocked_request(ip:, user_agent:, path:, http_method:, block_reason:)
        raise NotImplementedError, "#{self.class}#track_blocked_request"
      end

      protected

      def perform_track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:,
                                  tracking_layer:, http_method:, prefetch: false)
        raise NotImplementedError, "#{self.class}#perform_track_page_view"
      end
    end
  end
end
