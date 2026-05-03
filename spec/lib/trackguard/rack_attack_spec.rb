# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::RackAttack do
  describe ".configure" do
    before { described_class.configure }
    after  { Rack::Attack.clear_configuration }

    it "registers the local safelist" do
      expect(Rack::Attack.safelists).to have_key("trackguard/allow local")
    end

    it "registers the whitelisted IPs safelist" do
      expect(Rack::Attack.safelists).to have_key("trackguard/allow whitelisted ips")
    end

    it "registers the scanner blocklist" do
      expect(Rack::Attack.blocklists).to have_key("trackguard/block known scanners")
    end

    it "registers the flagged visitors blocklist" do
      expect(Rack::Attack.blocklists).to have_key("trackguard/flagged visitors")
    end

    it "registers the IP throttle" do
      expect(Rack::Attack.throttles).to have_key("trackguard/requests by ip")
    end
  end

  describe "safelist: allow local" do
    before { described_class.configure }
    after  { Rack::Attack.clear_configuration }

    def req(ip)
      Rack::Attack::Request.new("REMOTE_ADDR" => ip, "REQUEST_METHOD" => "GET", "PATH_INFO" => "/")
    end

    it "safelists 127.0.0.1" do
      expect(Rack::Attack.safelists["trackguard/allow local"].matched_by?(req("127.0.0.1"))).to be true
    end

    it "safelists ::1" do
      expect(Rack::Attack.safelists["trackguard/allow local"].matched_by?(req("::1"))).to be true
    end

    it "does not safelist external IPs" do
      expect(Rack::Attack.safelists["trackguard/allow local"].matched_by?(req("1.2.3.4"))).to be_falsey
    end
  end

  describe "safelist: allow whitelisted ips" do
    before { described_class.configure }
    after  { Rack::Attack.clear_configuration }

    def req(ip)
      Rack::Attack::Request.new("REMOTE_ADDR" => ip, "REQUEST_METHOD" => "GET", "PATH_INFO" => "/")
    end

    it "safelists an active whitelisted IP" do
      Rails.cache.clear
      create(:whitelisted_ip, ip: "10.0.0.1")
      expect(Rack::Attack.safelists["trackguard/allow whitelisted ips"].matched_by?(req("10.0.0.1"))).to be true
    end

    it "does not safelist an IP not in the whitelist" do
      Rails.cache.clear
      expect(Rack::Attack.safelists["trackguard/allow whitelisted ips"].matched_by?(req("10.0.0.1"))).to be_falsey
    end

    it "does not safelist an expired whitelisted IP" do
      Rails.cache.clear
      create(:whitelisted_ip, :expired, ip: "10.0.0.1")
      expect(Rack::Attack.safelists["trackguard/allow whitelisted ips"].matched_by?(req("10.0.0.1"))).to be_falsey
    end
  end

  describe "blocklist: block known scanners" do
    before { described_class.configure }
    after  { Rack::Attack.clear_configuration }

    let(:blocked_agent) { create(:blocked_user_agent) }

    it "blocks a request matching a blocked user agent" do
      Rails.cache.clear
      req = Rack::Attack::Request.new(
        "REMOTE_ADDR" => "1.2.3.4",
        "HTTP_USER_AGENT" => blocked_agent.pattern,
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/"
      )
      expect(Rack::Attack.blocklists["trackguard/block known scanners"].matched_by?(req)).to be true
    end

    it "does not block a normal user agent" do
      req = Rack::Attack::Request.new(
        "REMOTE_ADDR" => "1.2.3.4",
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/"
      )
      expect(Rack::Attack.blocklists["trackguard/block known scanners"].matched_by?(req)).to be_falsey
    end
  end

  describe "blocklist: flagged visitors" do
    before { described_class.configure }
    after  { Rack::Attack.clear_configuration }

    let!(:flagged) { create(:visitor, :flagged, ip: "5.6.7.8") }

    it "blocks a flagged IP" do
      Rails.cache.clear
      req = Rack::Attack::Request.new("REMOTE_ADDR" => "5.6.7.8", "REQUEST_METHOD" => "GET", "PATH_INFO" => "/")
      expect(Rack::Attack.blocklists["trackguard/flagged visitors"].matched_by?(req)).to be true
    end

    it "does not block an unflagged IP" do
      Rails.cache.clear
      req = Rack::Attack::Request.new("REMOTE_ADDR" => "9.9.9.9", "REQUEST_METHOD" => "GET", "PATH_INFO" => "/")
      expect(Rack::Attack.blocklists["trackguard/flagged visitors"].matched_by?(req)).to be_falsey
    end
  end

  describe "throttle configuration" do
    after do
      Rack::Attack.clear_configuration
      Trackguard.instance_variable_set(:@throttle_limit, nil)
      Trackguard.instance_variable_set(:@throttle_period, nil)
    end

    it "uses default limit of 100" do
      described_class.configure
      expect(Rack::Attack.throttles["trackguard/requests by ip"].limit).to eq(100)
    end

    it "uses default period of 60" do
      described_class.configure
      expect(Rack::Attack.throttles["trackguard/requests by ip"].period).to eq(60)
    end

    it "respects a custom throttle limit" do
      Trackguard.throttle_limit = 50
      described_class.configure
      expect(Rack::Attack.throttles["trackguard/requests by ip"].limit).to eq(50)
    end

    it "respects a custom throttle period" do
      Trackguard.throttle_period = 30
      described_class.configure
      expect(Rack::Attack.throttles["trackguard/requests by ip"].period).to eq(30)
    end
  end
end
