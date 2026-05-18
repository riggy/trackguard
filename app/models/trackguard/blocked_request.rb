# frozen_string_literal: true

module Trackguard
  class BlockedRequest < Visit
    REASON_SCANNER = "trackguard/block known scanners"
    REASON_FLAGGED = "trackguard/flagged visitors"
    REASON_PROBE   = "trackguard/block known paths"

    validates :path, :block_reason, presence: true

    scope :scanners, -> { where(block_reason: REASON_SCANNER) }
    scope :flagged,  -> { where(block_reason: REASON_FLAGGED) }
    scope :probes,   -> { where(block_reason: REASON_PROBE) }
  end
end
