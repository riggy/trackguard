module Trackguard
  class PageView < Visit
    validates :path, presence: true

    scope :this_week,     -> { where(created_at: 1.week.ago..) }
    scope :this_month,    -> { where(created_at: 1.month.ago..) }
    scope :with_referrer, -> { where.not(referer: [ nil, "" ]) }
    scope :with_source,   -> { where.not(source: [ nil, "" ]) }

    def js_layer?      = tracking_layer == "js"
    def backend_layer? = tracking_layer == "backend"
  end
end
