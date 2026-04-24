module Trackguard
  class WhitelistedIp < ApplicationRecord
    self.table_name = "trackguard_whitelisted_ips"

    belongs_to :visitor, class_name: "Trackguard::Visitor", optional: true

    validates :ip,         presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :active, -> { where(expires_at: Time.current..) }

    def self.whitelisted?(ip)
      active.exists?(ip: ip)
    end

    def active?
      expires_at > Time.current
    end
  end
end
