module Trackguard
  class Visitor < ApplicationRecord
    self.table_name = "trackguard_visitors"

    FLAGGED_BY        = [ "User", "claw:auto", "Recurring Job", "Internal Automation", "External Automation" ].freeze
    SUSPICIOUS_STATES = %w[normal suspicious blocked].freeze
    CACHE_KEY         = "trackguard/flagged_ips".freeze

    validates :flagged_by, inclusion: { in: FLAGGED_BY }, allow_blank: true
    validates :suspicious_state, inclusion: { in: SUSPICIOUS_STATES }

    has_many :page_views,       class_name: "Trackguard::PageView", foreign_key: "visitor_id"
    has_many :blocked_requests, class_name: "Trackguard::BlockedRequest",  foreign_key: "visitor_id"
    has_one  :whitelisted_ip,   class_name: "Trackguard::WhitelistedIp",   foreign_key: "visitor_id"

    scope :unflagged,           -> { where(flagged_at: nil) }
    scope :flagged,             -> { where.not(flagged_at: nil) }
    scope :suspicious_visitors, -> { where(suspicious_state: "suspicious") }
    scope :blocked,             -> { where(suspicious_state: "blocked") }

    def normal?     = suspicious_state == "normal"
    def suspicious? = suspicious_state == "suspicious"
    def blocked?    = suspicious_state == "blocked"

    def self.flagged?(ip)
      flagged_ips = Rails.cache.fetch(CACHE_KEY, expires_in: 5.minutes) do
        flagged.pluck(:ip)
      end

      flagged_ips.include?(ip)
    end
  end
end
