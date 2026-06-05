module Trackguard
  module ApplicationHelper
    def trackguard_header_tags
      return "".html_safe unless Trackguard.tracking_enabled?

      tags = [ tag.meta(name: "trace-id", content: @trace_id) ]

      case Trackguard.adapter
      when Trackguard::Adapters::Local
        tags << tag.meta(name: "trackguard-url", content: trackguard.page_views_path)
      when Trackguard::Adapters::Hub
        if Rails.env.production?
          tags << tag.script(src: "#{Trackguard.hub_url}/track.js", data: { api_key: Trackguard.hub_api_key })
        end
      end

      safe_join(tags, "\n")
    end

    def trackguard_nav_links
      [
        { label: "Dashboard", url: dashboard_path, active: request.path == dashboard_path },
        { label: "All Visits", url: visits_path,   active: request.path.start_with?(visits_path) }
      ]
    end

    def trackguard_visits_page_url
      ->(n) { visits_path(page: n) }
    end

    def trackguard_visit_row_actions(visitor)
      {
        flag: { url: flag_visitor_path, method: :patch, params: { id: visitor.id } },
        unflag: { url: unflag_visitor_path, method: :patch, params: { id: visitor.id } },
        whitelist: { url: whitelist_visitor_path, method: :patch, params: { id: visitor.id } },
        unwhitelist: { url: unwhitelist_visitor_path, method: :patch, params: { id: visitor.id } }
      }
    end
  end
end
