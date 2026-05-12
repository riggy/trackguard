module Trackguard
  module Admin
    class VisitsController < BaseController
      include Overridable

      PER_PAGE = 20

      def index
        @page   = [ (params[:page] || 1).to_i, 1 ].max
        @total  = page_view_scope.count
        @pages  = (@total.to_f / PER_PAGE).ceil
        @visits = page_view_scope.order(created_at: :desc)
                                 .limit(PER_PAGE)
                                 .offset((@page - 1) * PER_PAGE)
                                 .includes(visitor: :whitelisted_ip)
      end
    end
  end
end
