class PageView < ApplicationRecord
  belongs_to :visitor

  validates :path, presence: true

  scope :today,      -> { where(created_at: Time.current.beginning_of_day..) }
  scope :this_week,  -> { where(created_at: 1.week.ago..) }
  scope :this_month, -> { where(created_at: 1.month.ago..) }
  scope :last_30,    -> { where(created_at: 30.days.ago..) }
  scope :last_24h,    -> { where(created_at: 24.hours.ago..) }
  scope :with_referrer, -> { where.not(referer: [ nil, "" ]) }
  scope :with_source,   -> { where.not(source: [ nil, "" ]) }
end
