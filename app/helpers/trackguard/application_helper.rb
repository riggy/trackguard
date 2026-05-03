module Trackguard
  module ApplicationHelper
    def trackguard_meta_tags
      safe_join([
                  tag.meta(name: "trackguard-url", content: trackguard.page_views_path),
                  tag.meta(name: "trace-id", content: @trace_id)
                ], "\n")
    end
  end
end
