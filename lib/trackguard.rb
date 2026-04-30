require "trackguard/version"
require "trackguard/engine"

module Trackguard
  class << self
    attr_writer :authenticate_admin_with
    attr_writer :admin_layout
    attr_writer :back_url
    attr_writer :back_label
    attr_writer :api_token

    def authenticate_admin_with
      @authenticate_admin_with ||= proc {}
    end

    def admin_layout
      @admin_layout ||= "trackguard/admin"
    end

    def back_url
      @back_url ||= "/admin"
    end

    def back_label
      @back_label ||= "Back to app"
    end

    def api_token
      @api_token.to_s
    end
  end
end
