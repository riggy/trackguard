class PageViewsController < ApplicationController
  def create
    PageViewRecorder.call(
      path:       params[:path].to_s,
      ip:         request.remote_ip,
      user_agent: request.user_agent.to_s,
      referer:    request.referer,
      session_id: session.id.to_s,
      trace_id:   params[:trace_id].to_s.presence,
      source:     params[:ref].to_s.strip.downcase.first(64).presence,
      initial:    params[:initial] == true
    )

    head :no_content
  end
end
