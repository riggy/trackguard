# frozen_string_literal: true

module Trackguard
  class TrackBlockedRequestJob < ApplicationJob
    queue_as :default

    def perform(ip:, user_agent:, path:, http_method:, block_reason:)
      TrackBlockedRequest.call(ip:, user_agent:, path:, http_method:, block_reason:)
    end
  end
end
