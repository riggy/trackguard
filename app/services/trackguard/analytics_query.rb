module Trackguard
  class AnalyticsQuery < ApplicationService
    attr_reader :totals, :top_pages, :top_referrers, :top_sources, :recent

    def initialize(scope:, time_scope:, limit:)
      @scope      = scope
      @time_scope = time_scope
      @limit      = limit
    end

    def call
      @totals = {
        today: @scope.today.count,
        week: @scope.this_week.count,
        month: @scope.this_month.count
      }

      @top_pages     = @time_scope.group(:path).order("count_all DESC").limit(@limit).count
      @top_referrers = @time_scope.with_referrer.group(:referer).order("count_all DESC").limit(@limit).count
      @top_sources   = @time_scope.with_source.group(:source).order("count_all DESC").limit(@limit).count

      @recent = @scope.order(created_at: :desc).limit(20).includes(visitor: :whitelisted_ip)

      self
    end
  end
end
