# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::WhitelistedIp, type: :model do
  describe "validations" do
    it "is valid with an ip and expires_at" do
      expect(build(:whitelisted_ip)).to be_valid
    end

    it "is invalid without an ip" do
      expect(build(:whitelisted_ip, ip: nil)).not_to be_valid
    end

    it "is invalid without expires_at" do
      expect(build(:whitelisted_ip, expires_at: nil)).not_to be_valid
    end

    it "is invalid with a duplicate ip" do
      create(:whitelisted_ip, ip: "1.2.3.4")
      expect(build(:whitelisted_ip, ip: "1.2.3.4")).not_to be_valid
    end
  end

  describe ".whitelisted?" do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it "returns false when no active records exist" do
      expect(described_class.whitelisted?("1.2.3.4")).to be false
    end

    it "returns true for an active whitelisted IP" do
      create(:whitelisted_ip, ip: "1.2.3.4")
      expect(described_class.whitelisted?("1.2.3.4")).to be true
    end

    it "returns false for an expired whitelisted IP" do
      create(:whitelisted_ip, :expired, ip: "1.2.3.4")
      expect(described_class.whitelisted?("1.2.3.4")).to be false
    end

    it "returns false for an IP not in the whitelist" do
      create(:whitelisted_ip, ip: "1.2.3.4")
      expect(described_class.whitelisted?("9.9.9.9")).to be false
    end

    it "serves subsequent calls from cache" do
      create(:whitelisted_ip, ip: "1.2.3.4")
      described_class.whitelisted?("1.2.3.4")

      described_class.delete_all
      expect(described_class.whitelisted?("1.2.3.4")).to be true
    end
  end

  describe "#active?" do
    it "returns true when expires_at is in the future" do
      expect(build(:whitelisted_ip).active?).to be true
    end

    it "returns false when expires_at is in the past" do
      expect(build(:whitelisted_ip, :expired).active?).to be false
    end
  end
end
