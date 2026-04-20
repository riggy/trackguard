module Trackguard
  class VisitorsController < BaseController
    before_action :set_visitor

    def flag
      @visitor.update!(
        flagged_at: Time.current,
        flag_reason: params[:flag_reason].presence,
        flagged_by: Visitor::FLAGGED_BY.first
      )
      redirect_back_or_to dashboard_path
    end

    def unflag
      @visitor.update!(flagged_at: nil, flag_reason: nil, flagged_by: nil)
      redirect_back_or_to dashboard_path
    end

    private

    def set_visitor
      @visitor = Visitor.find(params[:id])
    end
  end
end