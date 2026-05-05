# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::BlockedRequest, type: :model do
  describe "validations" do
    it "is valid with path and block_reason" do
      expect(build(:blocked_request)).to be_valid
    end

    it "is invalid without path" do
      expect(build(:blocked_request, path: nil)).not_to be_valid
    end

    it "is invalid without block_reason" do
      expect(build(:blocked_request, block_reason: nil)).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:scanner) { create(:blocked_request, block_reason: described_class::REASON_SCANNER) }
    let!(:flagged) { create(:blocked_request, block_reason: described_class::REASON_FLAGGED) }

    it "scanners returns only scanner-blocked requests" do
      expect(described_class.scanners).to eq([ scanner ])
    end

    it "flagged returns only flagged-visitor blocks" do
      expect(described_class.flagged).to eq([ flagged ])
    end
  end

  describe "visitor association" do
    it "belongs to a visitor" do
      visitor = create(:visitor)
      record  = create(:blocked_request, visitor: visitor)
      expect(record.visitor).to eq(visitor)
    end
  end
end
