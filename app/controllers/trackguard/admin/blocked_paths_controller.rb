module Trackguard
  module Admin
    class BlockedPathsController < BaseController
      skip_before_action :verify_authenticity_token, if: :valid_api_token?

      def index
        render json: BlockedPath.order(:pattern).pluck(:pattern)
      end

      def create
        record = BlockedPath.find_or_create_by!(pattern: params.fetch(:pattern))
        Rails.cache.delete(BlockedPath::CACHE_KEY)
        render json: { status: "ok", pattern: record.pattern }
      rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
        render json: { status: "error", message: e.message }, status: :unprocessable_content
      end

      private

      def authenticate_admin!
        return if valid_api_token?

        super
      end
    end
  end
end
