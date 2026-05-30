# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::Adapters::Hub do
  let(:hub_url) { "https://hub.example.com" }
  let(:adapter) { described_class.new }
  let(:rules_url) { "#{hub_url}/api/backend/rules" }

  let(:rules_payload) do
    {
      blocked_user_agents: %w[AhrefsBot SemrushBot],
      blocked_paths: [ "/wp-admin", "/.env" ],
      whitelisted_ips: [ "1.2.3.4" ],
      flagged_ips: [ "9.9.9.9" ]
    }
  end

  before do
    Trackguard.hub_url = hub_url
    Trackguard.hub_secret_key = "test-token"
    Trackguard.hub_api_key = "test-api-key"
    [ described_class::CACHE_KEY, described_class::STALE_KEY, described_class::ETAG_KEY ].each do |key|
      Rails.cache.delete(key)
    end
  end

  after do
    Trackguard.hub_url = nil
    Trackguard.hub_secret_key = nil
    Trackguard.hub_api_key = nil
  end

  def stub_hub(status: 200, body: rules_payload.to_json, etag: nil)
    headers = { "Content-Type" => "application/json" }
    headers["ETag"] = etag if etag
    stub_request(:get, rules_url)
      .with(headers: { "Authorization" => "Bearer test-token", "X-Api-Key" => "test-api-key",
                       "Accept" => "application/json" })
      .to_return(status: status, body: body, headers: headers)
  end

  describe "#blocked_user_agent?" do
    it "returns true for a case-insensitive substring match" do
      stub_hub
      expect(adapter.blocked_user_agent?("AhrefsBot/7.0")).to be true
    end

    it "matches when pattern appears mid-string" do
      stub_hub
      expect(adapter.blocked_user_agent?("Mozilla/5.0 SemrushBot/6.1")).to be true
    end

    it "returns false when no pattern matches" do
      stub_hub
      expect(adapter.blocked_user_agent?("Mozilla/5.0 Chrome/124")).to be false
    end

    it "returns false for a nil user agent" do
      stub_hub
      expect(adapter.blocked_user_agent?(nil)).to be false
    end
  end

  describe "#blocked_path?" do
    it "returns true for a matching path pattern" do
      stub_hub
      expect(adapter.blocked_path?("/wp-admin/login")).to be true
    end

    it "returns false for a non-matching path" do
      stub_hub
      expect(adapter.blocked_path?("/dashboard")).to be false
    end
  end

  describe "#whitelisted_ip?" do
    it "returns true for an exact IP match" do
      stub_hub
      expect(adapter.whitelisted_ip?("1.2.3.4")).to be true
    end

    it "returns false for a non-whitelisted IP" do
      stub_hub
      expect(adapter.whitelisted_ip?("5.6.7.8")).to be false
    end
  end

  describe "#flagged_visitor?" do
    it "returns true for a flagged IP" do
      stub_hub
      expect(adapter.flagged_visitor?("9.9.9.9")).to be true
    end

    it "returns false for an unflagged IP" do
      stub_hub
      expect(adapter.flagged_visitor?("1.1.1.1")).to be false
    end
  end

  describe "#track_blocked_request" do
    it "enqueues SubmitBlockedRequestJob with the correct arguments" do
      expect do
        adapter.track_blocked_request(ip: "1.2.3.4", user_agent: "bot", path: "/", http_method: "GET",
                                      block_reason: "test")
      end.to have_enqueued_job(Trackguard::Hub::SubmitBlockedRequestJob)
        .with(ip: "1.2.3.4", user_agent: "bot", path: "/", http_method: "GET", block_reason: "test")
    end
  end

  describe "caching" do
    it "makes one HTTP request on cache miss" do
      request = stub_hub
      adapter.blocked_user_agent?("bot")
      expect(request).to have_been_made.once
    end

    it "skips HTTP on subsequent calls within the TTL" do
      request = stub_hub
      adapter.blocked_user_agent?("bot")
      adapter.blocked_path?("/wp-admin")
      expect(request).to have_been_made.once
    end
  end

  describe "failure handling" do
    context "when hub returns a non-2xx response" do
      it "returns false (fail-open) with no stale cache" do
        stub_hub(status: 503, body: "")
        expect(adapter.blocked_user_agent?("AhrefsBot")).to be false
      end

      it "falls back to stale rules" do
        Rails.cache.write(described_class::STALE_KEY, rules_payload, expires_in: 24.hours)
        stub_hub(status: 503, body: "")
        expect(adapter.blocked_user_agent?("AhrefsBot")).to be true
      end
    end

    context "when hub is unreachable" do
      it "returns false (fail-open) with no stale cache" do
        stub_request(:get, rules_url).to_raise(Errno::ECONNREFUSED)
        expect(adapter.blocked_user_agent?("AhrefsBot")).to be false
      end

      it "falls back to stale rules" do
        Rails.cache.write(described_class::STALE_KEY, rules_payload, expires_in: 24.hours)
        stub_request(:get, rules_url).to_raise(Errno::ECONNREFUSED)
        expect(adapter.blocked_user_agent?("AhrefsBot")).to be true
      end
    end
  end

  describe "ETag support" do
    it "stores the ETag from a successful response" do
      stub_hub(etag: '"abc123"')
      adapter.blocked_user_agent?("bot")
      expect(Rails.cache.read(described_class::ETAG_KEY)).to eq('"abc123"')
    end

    it "sends If-None-Match when an ETag is cached" do
      Rails.cache.write(described_class::ETAG_KEY, '"abc123"', expires_in: 24.hours)
      Rails.cache.write(described_class::STALE_KEY, rules_payload, expires_in: 24.hours)
      request = stub_request(:get, rules_url)
                .with(headers: { "If-None-Match" => '"abc123"' })
                .to_return(status: 304, body: "", headers: {})
      adapter.blocked_user_agent?("bot")
      expect(request).to have_been_made
    end

    it "returns stale rules on 304 Not Modified" do
      Rails.cache.write(described_class::ETAG_KEY, '"abc123"', expires_in: 24.hours)
      Rails.cache.write(described_class::STALE_KEY, rules_payload, expires_in: 24.hours)
      stub_request(:get, rules_url).to_return(status: 304, body: "", headers: {})
      expect(adapter.blocked_user_agent?("AhrefsBot")).to be true
    end

    it "writes fresh rules to the stale cache on a new 200 response" do
      stub_hub(etag: '"new-etag"')
      adapter.blocked_user_agent?("bot")
      expect(Rails.cache.read(described_class::STALE_KEY)).to eq(rules_payload)
    end
  end
end
