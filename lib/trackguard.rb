# frozen_string_literal: true

require "trackguard/version"
require "trackguard/engine"
require "trackguard/rack_attack"
require "trackguard/trace_id_middleware"
require "trackguard/adapters/base"
require "trackguard/adapters/local"
require "trackguard/adapters/hub"

module Trackguard
  class ConfigurationError < StandardError; end

  class << self
    def configure
      @_configuring = true
      yield self
    ensure
      @_configuring = false
    end

    # Setters — use configure block; direct assignment is deprecated.

    def authenticate_admin_with=(value)
      deprecated_direct_setter(:authenticate_admin_with)
      @authenticate_admin_with = value
    end

    def admin_layout=(value)
      deprecated_direct_setter(:admin_layout)
      @admin_layout = value
    end

    def admin_path=(value)
      deprecated_direct_setter(:admin_path)
      @admin_path = value
    end

    def back_label=(value)
      deprecated_direct_setter(:back_label)
      @back_label = value
    end

    def local_api_token=(value)
      deprecated_direct_setter(:local_api_token)
      @local_api_token = value
    end

    def throttle_limit=(value)
      deprecated_direct_setter(:throttle_limit)
      @throttle_limit = value
    end

    def throttle_period=(value)
      deprecated_direct_setter(:throttle_period)
      @throttle_period = value
    end

    def hub_url=(value)
      deprecated_direct_setter(:hub_url)
      @hub_url = value
    end

    def hub_secret_key=(value)
      deprecated_direct_setter(:hub_secret_key)
      @hub_secret_key = value
    end

    def hub_api_key=(value)
      deprecated_direct_setter(:hub_api_key)
      @hub_api_key = value
    end

    def hub_rules_ttl=(value)
      deprecated_direct_setter(:hub_rules_ttl)
      @hub_rules_ttl = value
    end

    def adapter=(value)
      deprecated_direct_setter(:adapter)
      @adapter = resolve_adapter(value)
    end

    def disable_on_development=(value)
      deprecated_direct_setter(:disable_on_development)
      @disable_on_development = value
    end

    # Readers

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

    def local_api_token
      @local_api_token.to_s
    end

    def throttle_limit
      @throttle_limit ||= 100
    end

    def throttle_period
      @throttle_period ||= 60
    end

    def hub_url
      @hub_url ||= "https://app.trackguard.dev"
    end

    def hub_secret_key = @hub_secret_key.to_s
    def hub_api_key    = @hub_api_key.to_s
    def hub_rules_ttl  = @hub_rules_ttl ||= 5.minutes

    def adapter
      @adapter ||= Trackguard::Adapters::Local.new
    end

    def disable_on_development
      @disable_on_development.nil? || @disable_on_development
    end

    def tracking_enabled?
      !disable_on_development || !Rails.env.development?
    end

    private

    def deprecated_direct_setter(attr)
      return if @_configuring

      warn "[DEPRECATED] Trackguard.#{attr}= called directly. " \
           "Use `Trackguard.configure { |c| c.#{attr} = ... }` instead. " \
           "Direct assignment will be removed in a future version."
    end

    def resolve_adapter(value)
      case value
      when Symbol then Trackguard::Adapters.const_get(value.to_s.camelize).new
      when Class  then value.new
      else             value
      end
    end
  end
end
