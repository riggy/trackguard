module Trackguard
  class Visitor < ApplicationRecord
    self.table_name = "trackguard_visitors"

    FLAGGED_BY = [ "User", "claw:auto", "Recurring Job", "Internal Automation", "External Automation" ].freeze
    CACHE_KEY = "trackguard/flagged_ips".freeze

    validates :flagged_by, inclusion: { in: FLAGGED_BY }, allow_blank: true

    has_many :page_views,       class_name: "Trackguard::PageView", foreign_key: "visitor_id"
    has_many :blocked_requests, class_name: "Trackguard::BlockedRequest",  foreign_key: "visitor_id"
    has_one  :whitelisted_ip,   class_name: "Trackguard::WhitelistedIp",   foreign_key: "visitor_id"

    scope :unflagged, -> { where(flagged_at: nil) }
    scope :flagged,   -> { where.not(flagged_at: nil) }

    def self.flagged?(ip)
      flagged_ips = Rails.cache.fetch(CACHE_KEY, expires_in: 5.minutes) do
        flagged.pluck(:ip)
      end

      flagged_ips.include?(ip)
    end
  end
end
