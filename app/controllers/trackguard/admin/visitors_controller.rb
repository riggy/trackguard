module Trackguard
  module Admin
    class VisitorsController < BaseController
      skip_before_action :verify_authenticity_token, if: :valid_api_token?
      before_action :set_visitor

      rescue_from ActiveRecord::RecordNotFound do
        respond_to do |format|
          format.html { redirect_to dashboard_path, alert: "Visitor not found." }
          format.json { render json: { error: "Visitor not found" }, status: :not_found }
        end
      end

      # rubocop:disable Metrics/AbcSize
      def flag
        if @visitor.update(
          flagged_at: Time.current,
          flag_reason: params[:flag_reason].presence,
          flagged_by: params[:flagged_by].presence || Visitor::FLAGGED_BY.first,
          name: params[:name].presence || BlockedUserAgent.matching_pattern(@visitor.user_agent)
        )
          respond_to do |format|
            format.html { redirect_back_or_to dashboard_path }
            format.json { render json: { status: "ok", ip: @visitor.ip, flagged_at: @visitor.flagged_at } }
          end
        else
          respond_to do |format|
            format.html { redirect_back_or_to dashboard_path, alert: @visitor.errors.full_messages.join(", ") }
            format.json { render json: { errors: @visitor.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end
      # rubocop:enable Metrics/AbcSize

      def unflag
        @visitor.update!(flagged_at: nil, flag_reason: nil, flagged_by: nil)
        respond_to do |format|
          format.html { redirect_back_or_to dashboard_path }
          format.json { render json: { status: "ok", ip: @visitor.ip } }
        end
      end

      private

      def authenticate_admin!
        return if valid_api_token?

        super
      end

      def set_visitor
        @visitor = if params[:ip].present?
                     Visitor.find_by!(ip: params[:ip])
                   else
                     Visitor.find(params[:id])
                   end
      end
    end
  end
end
