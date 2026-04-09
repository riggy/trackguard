class PageViewRecorder < ApplicationService
  BOT_REGEX = /Googlebot|Bingbot|Slurp|DuckDuckBot|Baidu|YandexBot|facebookexternalhit|Twitterbot|LinkedInBot|curl|wget|python-requests|python-urllib|Go-http-client|libwww|Java|Ruby|bot|crawl|spider/i

  def initialize(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source: nil, initial: false)
    @path       = path.to_s
    @ip         = ip
    @user_agent = user_agent.to_s
    @referer    = referer
    @session_id = session_id
    @trace_id   = trace_id
    @source     = source.presence
    @initial    = initial
  end

  def call
    return if BOT_REGEX.match?(@user_agent)
    return if @path.blank? || @path.start_with?("/admin")

    TrackPageViewJob.perform_later(
      path:       @path,
      ip:         @ip,
      user_agent: @user_agent,
      referer:    @referer,
      session_id: @session_id,
      trace_id:   @trace_id,
      source:     @source,
      initial:    @initial
    )
  end
end
