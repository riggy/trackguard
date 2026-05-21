module Trackguard
  class TrackPageViewJob < ApplicationJob
    queue_as :default

    def perform(path:, ip:, user_agent:, referer:, session_id: nil, trace_id: nil, source: nil,
                tracking_layer: nil, http_method: nil)
      TrackPageView.call(path:, ip:, user_agent:, referer:, session_id:, trace_id:, source:, tracking_layer:,
                         http_method:)
    end
  end
end
