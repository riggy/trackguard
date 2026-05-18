require "rails_helper"

RSpec.describe Trackguard::BlockedPath, type: :model do
  describe "validations" do
    it "is valid with a pattern" do
      expect(build(:blocked_path)).to be_valid
    end

    it "is invalid without a pattern" do
      expect(build(:blocked_path, pattern: nil)).not_to be_valid
    end

    it "is invalid with a duplicate pattern" do
      create(:blocked_path, pattern: "/.env")
      expect(build(:blocked_path, pattern: "/.env")).not_to be_valid
    end
  end

  describe ".blocked?" do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it "returns false when no patterns exist" do
      expect(described_class.blocked?("/.env")).to be false
    end

    it "returns true for a substring match" do
      create(:blocked_path, pattern: "/.env")
      expect(described_class.blocked?("/.env")).to be true
    end

    it "matches case-insensitively" do
      create(:blocked_path, pattern: "/.ENV")
      expect(described_class.blocked?("/.env")).to be true
    end

    it "matches a probe path with a suffix" do
      create(:blocked_path, pattern: "/.env")
      expect(described_class.blocked?("/.env.backup")).to be true
    end

    it "returns false when no pattern matches" do
      create(:blocked_path, pattern: "/.env")
      expect(described_class.blocked?("/posts/hello")).to be false
    end

    it "returns false for a nil path" do
      create(:blocked_path, pattern: "/.env")
      expect(described_class.blocked?(nil)).to be false
    end
  end

  describe ".matching_pattern" do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it "returns nil when no patterns exist" do
      expect(described_class.matching_pattern("/wp-login.php")).to be_nil
    end

    it "returns the matching pattern string" do
      create(:blocked_path, pattern: "/wp-login.php")
      expect(described_class.matching_pattern("/wp-login.php")).to eq("/wp-login.php")
    end

    it "returns nil when no pattern matches" do
      create(:blocked_path, pattern: "/wp-login.php")
      expect(described_class.matching_pattern("/posts/hello")).to be_nil
    end
  end
end
