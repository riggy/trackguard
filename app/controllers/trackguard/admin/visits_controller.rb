module Trackguard
  module Admin
    class VisitsController < BaseController
      PER_PAGE = 20

      def index
        @page   = [ (params[:page] || 1).to_i, 1 ].max
        @total  = PageView.count
        @pages  = (@total.to_f / PER_PAGE).ceil
        @visits = PageView.order(created_at: :desc)
                          .limit(PER_PAGE)
                          .offset((@page - 1) * PER_PAGE)
                          .includes(visitor: :whitelisted_ip)
      end
    end
  end
end
