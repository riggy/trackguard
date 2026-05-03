module Trackguard
  class WhitelistedIp < ApplicationRecord
    self.table_name = "trackguard_whitelisted_ips"

    CACHE_KEY = "trackguard/whitelisted_ips".freeze

    belongs_to :visitor, class_name: "Trackguard::Visitor", optional: true

    validates :ip,         presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :active, -> { where(expires_at: Time.current..) }

    def self.whitelisted?(ip)
      active_ips = Rails.cache.fetch(CACHE_KEY, expires_in: 10.minutes) do
        active.pluck(:ip)
      end

      active_ips.include?(ip)
    end

    def active?
      expires_at > Time.current
    end
  end
end
