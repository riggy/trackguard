# frozen_string_literal: true

module Trackguard
  class Visit < ApplicationRecord
    self.table_name = "trackguard_visits"

    belongs_to :visitor, class_name: "Trackguard::Visitor"

    scope :today,    -> { where(created_at: Time.current.beginning_of_day..) }
    scope :last_24h, -> { where(created_at: 24.hours.ago..) }
    scope :last_30,  -> { where(created_at: 30.days.ago..) }
  end
end
