module Trackguard
  module Admin
    class DashboardsController < BaseController
      include Overridable

      def show
        query = AnalyticsQuery.call(
          scope: page_view_scope,
          time_scope: page_view_scope.last_30,
          limit: 5
        )

        @total_today   = query.totals[:today]
        @total_week    = query.totals[:week]
        @total_month   = query.totals[:month]
        @top_pages     = query.top_pages
        @top_referrers = query.top_referrers
        @top_sources   = query.top_sources
        @recent        = query.recent
      end
    end
  end
end
