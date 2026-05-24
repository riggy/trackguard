module Trackguard
  module Admin
    class AnalyticsController < BaseController
      include Overridable

      skip_before_action :verify_authenticity_token, if: :valid_api_token?

      def show
        query = AnalyticsQuery.call(
          scope: page_view_scope,
          time_scope: apply_time_scope(page_view_scope),
          limit: 10
        )

        render json: {
          totals: query.totals,
          top_pages: query.top_pages,
          top_referrers: query.top_referrers,
          top_sources: query.top_sources,
          recent: visitor_filtered(apply_time_scope(query.recent)).map { |view| serialize_page_view(view) }
        }
      end

      private

      def authenticate_admin!
        return if valid_api_token?

        super
      end

      def apply_time_scope(base)
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
          flagged_scope = cast_bool(params[:flagged]) ? Visitor.flagged : Visitor.unflagged
          scope = scope.joins(:visitor).merge(flagged_scope)
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

      def serialize_page_view(view)
        {
          path: view.path,
          ip: view.visitor&.ip,
          suspicious_state: view.visitor.suspicious_state,
          flagged_at: view.visitor.flagged_at,
          flagged_by: view.visitor.flagged_by,
          whitelisted: view.visitor.whitelisted_ip&.active? || false,
          user_agent: view.user_agent,
          session_id: view.session_id,
          trace_id: view.trace_id,
          referer: view.referer,
          source: view.source,
          created_at: view.created_at
        }
      end
    end
  end
end
