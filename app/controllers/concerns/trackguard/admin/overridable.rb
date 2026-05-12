module Trackguard
  module Admin
    module Overridable
      extend ActiveSupport::Concern

      private

      def visitor_scope
        Visitor.all
      end

      def page_view_scope
        PageView.all
      end

      def after_action_path
        dashboard_path
      end

      def set_visitor
        @visitor = if params[:ip].present?
                     visitor_scope.find_by!(ip: params[:ip])
                   else
                     visitor_scope.find(params[:id])
                   end
      end
    end
  end
end
