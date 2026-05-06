# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::Adapters::Local do
  subject(:adapter) { described_class.new }

  describe "#blocked_user_agent?" do
    before { Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY) }

    it "returns true for a matching pattern" do
      create(:blocked_user_agent, pattern: "BadBot")
      expect(adapter.blocked_user_agent?("BadBot/1.0")).to be true
    end

    it "returns false when no pattern matches" do
      expect(adapter.blocked_user_agent?("Mozilla/5.0")).to be false
    end
  end

  describe "#whitelisted_ip?" do
    before { Rails.cache.delete(Trackguard::WhitelistedIp::CACHE_KEY) }

    it "returns true for an active whitelisted IP" do
      create(:whitelisted_ip, ip: "10.0.0.1")
      expect(adapter.whitelisted_ip?("10.0.0.1")).to be true
    end

    it "returns false for an expired whitelisted IP" do
      create(:whitelisted_ip, :expired, ip: "10.0.0.2")
      expect(adapter.whitelisted_ip?("10.0.0.2")).to be false
    end

    it "returns false for an unknown IP" do
      expect(adapter.whitelisted_ip?("9.9.9.9")).to be false
    end
  end

  describe "#flagged_visitor?" do
    before { Rails.cache.delete(Trackguard::Visitor::CACHE_KEY) }

    it "returns true for a flagged visitor IP" do
      create(:visitor, :flagged, ip: "5.6.7.8")
      expect(adapter.flagged_visitor?("5.6.7.8")).to be true
    end

    it "returns false for an unflagged visitor IP" do
      create(:visitor, ip: "1.1.1.1")
      expect(adapter.flagged_visitor?("1.1.1.1")).to be false
    end
  end

  describe "#track_page_view" do
    it "enqueues TrackPageViewJob with the given arguments" do
      expect do
        adapter.track_page_view(
          path: "/posts", ip: "1.2.3.4", user_agent: "Mozilla/5.0",
          referer: "https://example.com", session_id: "abc", trace_id: "xyz",
          source: "linkedin", initial: true, http_method: "GET"
        )
      end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(
        path: "/posts", ip: "1.2.3.4", user_agent: "Mozilla/5.0",
        referer: "https://example.com", session_id: "abc", trace_id: "xyz",
        source: "linkedin", initial: true, http_method: "GET"
      )
    end
  end

  describe "#track_blocked_request" do
    it "enqueues TrackBlockedRequestJob with the given arguments" do
      expect do
        adapter.track_blocked_request(
          ip: "1.2.3.4", user_agent: "ScannerBot/1.0",
          path: "/secret", http_method: "GET",
          block_reason: Trackguard::BlockedRequest::REASON_SCANNER
        )
      end.to have_enqueued_job(Trackguard::TrackBlockedRequestJob).with(
        ip: "1.2.3.4", user_agent: "ScannerBot/1.0",
        path: "/secret", http_method: "GET",
        block_reason: Trackguard::BlockedRequest::REASON_SCANNER
      )
    end
  end
end
