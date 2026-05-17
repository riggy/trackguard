# frozen_string_literal: true

require "trackguard/version"
require "trackguard/engine"
require "trackguard/rack_attack"
require "trackguard/adapters/base"
require "trackguard/adapters/local"

module Trackguard
  class << self
    attr_writer :authenticate_admin_with, :admin_layout, :admin_path, :back_label, :api_token, :throttle_limit,
                :throttle_period

    def authenticate_admin_with
      @authenticate_admin_with ||= proc {}
    end

    def admin_layout
      @admin_layout ||= "trackguard/admin"
    end

    def admin_path
      @admin_path ||= "/admin"
    end

    def back_label
      @back_label ||= "Back to app"
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

    def adapter
      @adapter ||= Trackguard::Adapters::Local.new
    end

    def adapter=(value)
      @adapter = resolve_adapter(value)
    end

    private

    def resolve_adapter(value)
      case value
      when Symbol then Trackguard::Adapters.const_get(value.to_s.camelize).new
      when Class  then value.new
      else             value
      end
    end
  end
end
