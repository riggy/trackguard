# frozen_string_literal: true

module Trackguard
  class TrackBlockedRequestJob < ApplicationJob
    queue_as :default

    def perform(ip:, user_agent:, path:, http_method:, block_reason:)
      visitor = Visitor.find_or_create_by!(ip: ip) do |v|
        v.user_agent    = user_agent
        v.first_seen_at = Time.current
        v.last_seen_at  = Time.current
      end
      visitor.update!(last_seen_at: Time.current, user_agent: user_agent)

      BlockedRequest.create!(
        path: path,
        user_agent: user_agent,
        http_method: http_method,
        block_reason: block_reason,
        visitor: visitor
      )
    end
  end
end
