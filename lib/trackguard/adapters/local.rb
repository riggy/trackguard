# frozen_string_literal: true

module Trackguard
  module Adapters
    class Local < Base
      def blocked_user_agent?(user_agent)
        BlockedUserAgent.blocked?(user_agent)
      end

      def whitelisted_ip?(ip)
        WhitelistedIp.whitelisted?(ip)
      end

      def flagged_visitor?(ip)
        Visitor.flagged?(ip)
      end

      def track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, initial:, http_method:)
        TrackPageViewJob.perform_later(
          path: path,
          ip: ip,
          user_agent: user_agent,
          referer: referer,
          session_id: session_id,
          trace_id: trace_id,
          source: source,
          initial: initial,
          http_method: http_method
        )
      end

      def track_blocked_request(ip:, user_agent:, path:, http_method:, block_reason:)
        TrackBlockedRequestJob.perform_later(
          ip: ip,
          user_agent: user_agent,
          path: path,
          http_method: http_method,
          block_reason: block_reason
        )
      end
    end
  end
end
