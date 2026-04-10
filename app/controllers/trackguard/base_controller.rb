module Trackguard
  class BaseController < ActionController::Base
    layout -> { Trackguard.admin_layout }

    before_action :authenticate_admin!

    private

    def authenticate_admin!
      instance_exec(&Trackguard.authenticate_admin_with)
    end
  end
end