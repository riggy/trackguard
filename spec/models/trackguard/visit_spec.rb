# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::Visit, type: :model do
  describe "scopes" do
    around { |e| travel_to(Time.current.noon, &e) }

    let!(:recent) { create(:page_view, created_at: 1.hour.ago) }
    let!(:old)    { create(:page_view, created_at: 60.days.ago) }

    it "today includes visits from today" do
      expect(described_class.today).to include(recent)
      expect(described_class.today).not_to include(old)
    end

    it "last_24h includes visits within 24 hours" do
      expect(described_class.last_24h).to include(recent)
      expect(described_class.last_24h).not_to include(old)
    end

    it "last_30 includes visits within 30 days" do
      expect(described_class.last_30).to include(recent)
      expect(described_class.last_30).not_to include(old)
    end
  end
end
