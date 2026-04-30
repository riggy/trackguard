module Trackguard
  module Admin
    class WhitelistedIpsController < BaseController
      skip_before_action :verify_authenticity_token, if: :valid_api_token?
      before_action :set_visitor

      rescue_from ActiveRecord::RecordNotFound do
        respond_to do |format|
          format.html { redirect_to dashboard_path, alert: "Visitor not found." }
          format.json { render json: { error: "Visitor not found" }, status: :not_found }
        end
      end

      def create
        record = WhitelistedIp.find_or_initialize_by(ip: @visitor.ip)
        record.visitor    = @visitor
        record.expires_at = params[:expires_at].presence || 7.days.from_now
        record.save!
        respond_to do |format|
          format.html { redirect_back_or_to dashboard_path }
          format.json { render json: { status: "ok", ip: @visitor.ip, expires_at: record.expires_at } }
        end
      rescue ActiveRecord::RecordInvalid => e
        respond_to do |format|
          format.html { redirect_back_or_to dashboard_path, alert: e.message }
          format.json { render json: { status: "error", message: e.message }, status: :unprocessable_entity }
        end
      end

      def destroy
        record = @visitor.whitelisted_ip

        if record
          record.destroy!
          respond_to do |format|
            format.html { redirect_back_or_to dashboard_path }
            format.json { render json: { status: "ok", ip: @visitor.ip } }
          end
        else
          respond_to do |format|
            format.html { redirect_back_or_to dashboard_path, alert: "No whitelist entry found." }
            format.json { render json: { error: "Not whitelisted" }, status: :not_found }
          end
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
