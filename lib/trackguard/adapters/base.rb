# frozen_string_literal: true

module Trackguard
  module Adapters
    class Base
      def blocked_user_agent?(user_agent) = raise NotImplementedError, "#{self.class}#blocked_user_agent?"
      def whitelisted_ip?(ip)             = raise NotImplementedError, "#{self.class}#whitelisted_ip?"
      def flagged_visitor?(ip)            = raise NotImplementedError, "#{self.class}#flagged_visitor?"

      def track_page_view(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, initial:, http_method:)
        raise NotImplementedError, "#{self.class}#track_page_view"
      end

      def track_blocked_request(ip:, user_agent:, path:, http_method:, block_reason:)
        raise NotImplementedError, "#{self.class}#track_blocked_request"
      end
    end
  end
end
