require "trackguard/version"
require "trackguard/engine"

module Trackguard
  class << self
    attr_writer :authenticate_admin_with
    attr_writer :admin_layout

    def authenticate_admin_with
      @authenticate_admin_with ||= proc {}
    end

    def admin_layout
      @admin_layout ||= "application"
    end
  end
end
