# frozen_string_literal: true

module Trackguard
  class BlockedPath < ApplicationRecord
    self.table_name = "trackguard_blocked_paths"

    CACHE_KEY = "trackguard/blocked_path_patterns"

    validates :pattern, presence: true, uniqueness: true

    def self.blocked?(path)
      patterns = Rails.cache.fetch(CACHE_KEY, expires_in: 10.minutes) do
        pluck(:pattern)
      end
      patterns.any? { |p| path.to_s.downcase.include?(p.downcase) }
    end

    def self.matching_pattern(path)
      patterns = Rails.cache.fetch(CACHE_KEY, expires_in: 10.minutes) do
        pluck(:pattern)
      end
      patterns.find { |p| path.to_s.downcase.include?(p.downcase) }
    end
  end
end
