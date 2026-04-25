
module Trackguard
  class DashboardsController < BaseController
    def show
      @total_today  = PageView.today.count
      @total_week   = PageView.this_week.count
      @total_month  = PageView.this_month.count

      @top_pages = PageView.last_30.group(:path).order("count_all DESC").limit(10).count
      @top_referrers = PageView.last_30.with_referrer.group(:referer).order("count_all DESC").limit(10).count
      @top_sources = PageView.last_30.with_source.group(:source).order("count_all DESC").limit(10).count

      @recent = PageView.order(created_at: :desc).limit(20).includes(visitor: :whitelisted_ip)
    end
  end
end