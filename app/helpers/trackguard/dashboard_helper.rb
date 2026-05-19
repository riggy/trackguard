# frozen_string_literal: true

module Trackguard
  module DashboardHelper
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
