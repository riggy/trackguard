require "rails_helper"

RSpec.describe Trackguard::AnalyticsQuery do
  let!(:recent_view) { create(:page_view, path: "/home",  created_at: 1.day.ago) }
  let!(:old_view)    { create(:page_view, path: "/about", created_at: 40.days.ago) }
  let!(:old_view2)   { create(:page_view, path: "/about", created_at: 35.days.ago) }

  let(:scope)      { Trackguard::PageView.all }
  let(:time_scope) { scope.last_30 }
  let(:query)      { described_class.call(scope: scope, time_scope: time_scope, limit: 5) }

  it "returns self from .call" do
    expect(query).to be_a(described_class)
  end

  describe "#totals" do
    it "counts today views from full scope" do
      expect(query.totals[:today]).to eq(0)
    end

    it "counts this_week views from full scope" do
      expect(query.totals[:week]).to eq(1)
    end

    it "counts this_month views from full scope" do
      expect(query.totals[:month]).to eq(1)
    end

    it "includes views outside the time_scope window" do
      expect(Trackguard::PageView.count).to eq(3)
      expect(query.totals[:month]).to eq(1)
    end
  end

  describe "#top_pages" do
    it "respects the time_scope window" do
      expect(query.top_pages.keys).to include("/home")
      expect(query.top_pages.keys).not_to include("/about")
    end

    it "respects the limit" do
      create_list(:page_view, 6, path: "/other", created_at: 1.day.ago)
      result = described_class.call(scope: scope, time_scope: time_scope, limit: 5)
      expect(result.top_pages.size).to be <= 5
    end
  end

  describe "#top_referrers" do
    it "only includes views with a referrer" do
      create(:page_view, referer: nil, created_at: 1.day.ago)
      result = described_class.call(scope: scope, time_scope: time_scope, limit: 5)
      expect(result.top_referrers.keys).to all(be_present)
    end
  end

  describe "#top_sources" do
    it "only includes views with a source" do
      create(:page_view, :with_source, created_at: 1.day.ago)
      result = described_class.call(scope: scope, time_scope: time_scope, limit: 5)
      expect(result.top_sources.keys).to all(be_present)
    end
  end

  describe "#recent" do
    it "is ordered newest first" do
      extra = create(:page_view, path: "/newer", created_at: Time.current)
      result = described_class.call(scope: scope, time_scope: time_scope, limit: 5)
      expect(result.recent.first).to eq(extra)
    end

    it "includes all-time views regardless of time_scope" do
      paths = query.recent.map(&:path)
      expect(paths).to include("/home")
      expect(paths).to include("/about")
    end

    it "is a chainable AR relation" do
      expect(query.recent).to respond_to(:where)
    end
  end
end
