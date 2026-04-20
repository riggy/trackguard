module Trackguard
  class Visitor < ApplicationRecord
    self.table_name = "trackguard_visitors"

    FLAGGED_BY = [ "User" ].freeze

    has_many :page_views, class_name: "Trackguard::PageView", foreign_key: "visitor_id"

    scope :unflagged, -> { where(flagged_at: nil) }
    scope :flagged,   -> { where.not(flagged_at: nil) }
  end
end
