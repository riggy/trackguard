# frozen_string_literal: true

require 'trackguard/version'
require 'trackguard/engine'
require 'trackguard/rack_attack'

module Trackguard
  class << self
    attr_writer :authenticate_admin_with, :admin_layout, :back_url, :back_label, :api_token, :throttle_limit,
                :throttle_period

    def authenticate_admin_with
      @authenticate_admin_with ||= proc {}
    end

    def admin_layout
      @admin_layout ||= 'trackguard/admin'
    end

    def back_url
      @back_url ||= '/admin'
    end

    def back_label
      @back_label ||= 'Back to app'
    end

    def api_token
      @api_token.to_s
    end

    def throttle_limit
      @throttle_limit ||= 100
    end

    def throttle_period
      @throttle_period ||= 60
    end
  end
end
