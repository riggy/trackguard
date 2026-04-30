module Trackguard
  module Admin
    class BaseController < ActionController::Base
      layout -> { Trackguard.admin_layout }

      before_action :authenticate_admin!

      private

      def authenticate_admin!
        instance_exec(&Trackguard.authenticate_admin_with)
      end

      def valid_api_token?
        expected = Trackguard.api_token
        return false unless expected.present?

        token = request.headers["Authorization"]&.then { |h| h[/\ABearer (.+)\z/, 1] }
        return false unless token.present?

        ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end
    end
  end
end
