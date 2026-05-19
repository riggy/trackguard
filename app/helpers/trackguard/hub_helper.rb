# frozen_string_literal: true

module Trackguard
  module HubHelper
    def trackguard_hub_js_tag
      return unless Trackguard.adapter.is_a?(Trackguard::Adapters::Hub)

      tag.script(src: "https://app.trackguard.dev/track.js", data: { api_key: Trackguard.hub_api_key })
    end
  end
end
