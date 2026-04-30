module Trackguard
  class AnalyticsController < BaseController
    skip_before_action :verify_authenticity_token, if: :valid_api_token?

    def show
      @total_today  = PageView.today.count
      @total_week   = PageView.this_week.count
      @total_month  = PageView.this_month.count

      base = time_scope
      @top_pages     = base.group(:path).order("count_all DESC").limit(10).count
      @top_referrers = base.with_referrer.group(:referer).order("count_all DESC").limit(10).count
      @top_sources   = base.with_source.group(:source).order("count_all DESC").limit(10).count

      @recent = visitor_filtered(
        time_scope(PageView.order(created_at: :desc).limit(20).includes(visitor: :whitelisted_ip))
      )

      render json: {
        totals: { today: @total_today, week: @total_week, month: @total_month },
        top_pages:     @top_pages,
        top_referrers: @top_referrers,
        top_sources:   @top_sources,
        recent: @recent.map { |pv|
          {
            path:        pv.path,
            ip:          pv.visitor&.ip,
            flagged_at:  pv.visitor.flagged_at,
            flagged_by:  pv.visitor.flagged_by,
            whitelisted: pv.visitor.whitelisted_ip&.active? || false,
            user_agent:  pv.user_agent,
            session_id:  pv.session_id,
            trace_id:    pv.trace_id,
            referer:     pv.referer,
            source:      pv.source,
            created_at:  pv.created_at
          }
        }
      }
    end

    private

    def authenticate_admin!
      return if valid_api_token?
      super
    end

    def time_scope(base = PageView.all)
      params[:since].present? ? base.where(created_at: parsed_since..) : base.last_30
    end

    def parsed_since
      @parsed_since ||= begin
        Date.parse(params[:since])
      rescue ArgumentError, TypeError
        30.days.ago.to_date
      end
    end

    def visitor_filtered(scope)
      if params.key?(:flagged)
        visitor_scope = cast_bool(params[:flagged]) ? Visitor.flagged : Visitor.unflagged
        scope = scope.joins(:visitor).merge(visitor_scope)
      end
      if params.key?(:whitelisted)
        scope = if cast_bool(params[:whitelisted])
          scope.joins(visitor: :whitelisted_ip).merge(WhitelistedIp.active)
        else
          scope.where.not(visitor_id: Visitor.joins(:whitelisted_ip).merge(WhitelistedIp.active).select(:id))
        end
      end
      scope
    end

    def cast_bool(val)
      ActiveRecord::Type::Boolean.new.cast(val)
    end
  end
end
