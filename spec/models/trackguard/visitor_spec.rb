# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trackguard::Visitor, type: :model do
  describe 'validations' do
    it 'is valid with valid flagged_by' do
      expect(build(:visitor, :flagged)).to be_valid
    end

    it 'is invalid with an unrecognised flagged_by value' do
      expect(build(:visitor, flagged_by: 'unknown')).not_to be_valid
    end

    it 'is valid with a blank flagged_by' do
      expect(build(:visitor, flagged_by: nil)).to be_valid
    end
  end

  describe '.flagged?' do
    before { Rails.cache.delete(described_class::CACHE_KEY) }

    it 'returns false when no flagged visitors exist' do
      create(:visitor)
      expect(described_class.flagged?('1.2.3.4')).to be false
    end

    it 'returns true for a flagged IP' do
      create(:visitor, :flagged, ip: '1.2.3.4')
      expect(described_class.flagged?('1.2.3.4')).to be true
    end

    it 'returns false for an unflagged IP' do
      create(:visitor, :flagged, ip: '1.2.3.4')
      expect(described_class.flagged?('9.9.9.9')).to be false
    end

    it 'serves subsequent calls from cache' do
      create(:visitor, :flagged, ip: '1.2.3.4')
      described_class.flagged?('1.2.3.4')

      described_class.where(ip: '1.2.3.4').delete_all
      expect(described_class.flagged?('1.2.3.4')).to be true
    end
  end
end