require "rails_helper"

RSpec.describe Trackguard::BlockedUserAgent, type: :model do
  describe "validations" do
    it "is valid with a pattern" do
      expect(build(:blocked_user_agent)).to be_valid
    end

    it "is invalid without a pattern" do
      expect(build(:blocked_user_agent, pattern: nil)).not_to be_valid
    end

    it "is invalid with a duplicate pattern" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(build(:blocked_user_agent, pattern: "AhrefsBot")).not_to be_valid
    end
  end

  describe ".matching_pattern" do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it "returns nil when no patterns exist" do
      expect(described_class.matching_pattern("Mozilla/5.0")).to be_nil
    end

    it "returns the matching pattern string" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.matching_pattern("AhrefsBot/7.0")).to eq("AhrefsBot")
    end

    it "matches case-insensitively" do
      create(:blocked_user_agent, pattern: "ahrefsbot")
      expect(described_class.matching_pattern("AhrefsBot/7.0")).to eq("ahrefsbot")
    end

    it "returns nil when no pattern matches" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.matching_pattern("Mozilla/5.0 Chrome/124")).to be_nil
    end

    it "returns nil for a nil user agent" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.matching_pattern(nil)).to be_nil
    end
  end

  describe ".blocked?" do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it "returns false when no patterns exist" do
      expect(described_class.blocked?("Mozilla/5.0")).to be false
    end

    it "returns true for a substring match" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.blocked?("AhrefsBot/7.0")).to be true
    end

    it "matches case-insensitively" do
      create(:blocked_user_agent, pattern: "ahrefsbot")
      expect(described_class.blocked?("AhrefsBot/7.0")).to be true
    end

    it "matches when pattern appears mid-string" do
      create(:blocked_user_agent, pattern: "SemrushBot")
      expect(described_class.blocked?("Mozilla/5.0 SemrushBot/6.1")).to be true
    end

    it "returns false when no pattern matches" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.blocked?("Mozilla/5.0 Chrome/124")).to be false
    end

    it "returns false for a nil user agent" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect(described_class.blocked?(nil)).to be false
    end
  end
end
