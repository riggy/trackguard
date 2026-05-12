module Trackguard
  module Admin
    class DashboardsController < BaseController
      include Overridable

      # rubocop:disable Metrics/AbcSize
      def show
        @total_today  = page_view_scope.today.count
        @total_week   = page_view_scope.this_week.count
        @total_month  = page_view_scope.this_month.count

        @top_pages     = page_view_scope.last_30.group(:path).order("count_all DESC").limit(5).count
        @top_referrers = page_view_scope.last_30.with_referrer.group(:referer).order("count_all DESC").limit(5).count
        @top_sources   = page_view_scope.last_30.with_source.group(:source).order("count_all DESC").limit(5).count

        @recent = page_view_scope.order(created_at: :desc).limit(20).includes(visitor: :whitelisted_ip)
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
