# frozen_string_literal: true

module Trackguard
  class TrackBlockedRequest < ApplicationService
    def initialize(ip:, user_agent:, path:, http_method:, block_reason:, visitor_scope: {})
      @ip           = ip
      @user_agent   = user_agent
      @path         = path
      @http_method  = http_method
      @block_reason = block_reason
      @visitor_scope = visitor_scope
    end

    def call
      visitor = Visitor.find_or_create_by!(ip: @ip, **@visitor_scope) do |v|
        v.user_agent    = @user_agent
        v.first_seen_at = Time.current
        v.last_seen_at  = Time.current
      end
      visitor.update!(last_seen_at: Time.current, user_agent: @user_agent)

      BlockedRequest.create!(
        path: @path,
        user_agent: @user_agent,
        http_method: @http_method,
        block_reason: @block_reason,
        visitor: visitor,
        **@visitor_scope
      )
    end
  end
end
