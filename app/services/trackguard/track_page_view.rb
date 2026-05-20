module Trackguard
  class TrackPageView < ApplicationService
    def initialize(path:, ip:, user_agent:, referer:, session_id: nil, trace_id: nil,
                   source: nil, initial: false, http_method: nil, visitor_scope: {})
      @path          = path
      @ip            = ip
      @user_agent    = user_agent
      @referer       = referer
      @session_id    = session_id
      @trace_id      = trace_id
      @source        = source
      @initial       = initial
      @http_method   = http_method
      @visitor_scope = visitor_scope
    end

    def call
      hashed_session_id = Digest::SHA256.hexdigest(@session_id) if @session_id.present?

      visitor = Visitor.find_or_create_by!(ip: @ip, **@visitor_scope) do |v|
        v.user_agent    = @user_agent
        v.first_seen_at = Time.current
        v.last_seen_at  = Time.current
      end
      visitor.update!(last_seen_at: Time.current, user_agent: @user_agent)

      if @initial && @trace_id.present?
        existing = PageView.find_by(trace_id: @trace_id, visitor: visitor)
        if existing
          if @path.include?("#") && !existing.path.include?("#") && @path.start_with?("#{existing.path}#")
            existing.update!(path: @path)
          end
          return
        end
      end

      PageView.create_with(source: @source, referer: @referer, http_method: @http_method, **@visitor_scope)
              .find_or_create_by!(path: @path, user_agent: @user_agent,
                                  session_id: hashed_session_id, trace_id: @trace_id, visitor: visitor)
    end
  end
end
