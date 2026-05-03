module Trackguard
  class BlockedUserAgent < ApplicationRecord
    self.table_name = "trackguard_blocked_user_agents"

    CACHE_KEY = "trackguard/blocked_user_agent_patterns"

    validates :pattern, presence: true, uniqueness: true

    def self.blocked?(user_agent)
      patterns = Rails.cache.fetch(CACHE_KEY, expires_in: 10.minutes) do
        pluck(:pattern)
      end
      patterns.any? { |p| user_agent.to_s.downcase.include?(p.downcase) }
    end
  end
end
