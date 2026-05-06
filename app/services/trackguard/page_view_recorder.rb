module Trackguard
  class PageViewRecorder < ApplicationService
    def initialize(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source: nil, initial: false,
                   http_method: nil)
      @path        = path.to_s
      @ip          = ip
      @user_agent  = user_agent.to_s
      @referer     = referer
      @session_id  = session_id
      @trace_id    = trace_id
      @source      = source.presence
      @initial     = initial
      @http_method = http_method
    end

    def call
      adapter = Trackguard.adapter
      return if adapter.blocked_user_agent?(@user_agent)
      return if @path.blank? || @path.start_with?("/admin")

      adapter.track_page_view(
        path: @path,
        ip: @ip,
        user_agent: @user_agent,
        referer: @referer,
        session_id: @session_id,
        trace_id: @trace_id,
        source: @source,
        initial: @initial,
        http_method: @http_method
      )
    end
  end
end
