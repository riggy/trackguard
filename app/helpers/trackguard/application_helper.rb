module Trackguard
  module ApplicationHelper
    def trackguard_hub_js_tag
      return unless Trackguard.adapter.is_a?(Trackguard::Adapters::Hub)

      tag.script(src: "https://app.trackguard.dev/track.js", data: { api_key: Trackguard.hub_api_key })
    end

    def trackguard_meta_tags
      safe_join([
                  tag.meta(name: "trackguard-url", content: trackguard.page_views_path),
                  tag.meta(name: "trace-id", content: @trace_id)
                ], "\n")
    end
  end
end
