require 'rails_helper'

RSpec.describe LglSetting do
  describe '.fetch and .store' do
    it 'returns nil for a key never stored' do
      expect(described_class.fetch('missing')).to be_nil
    end

    it 'round-trips a value as a string' do
      described_class.store('answer', 42)
      expect(described_class.fetch('answer')).to eq('42')
    end

    it 'overwrites an existing key rather than adding a row' do
      described_class.store('answer', 'first')
      described_class.store('answer', 'second')
      expect(described_class.fetch('answer')).to eq('second')
      expect(described_class.where(key: 'answer').count).to eq(1)
    end
  end

  describe '.campaign' do
    it 'is nil when no campaign has been chosen' do
      expect(described_class.campaign).to be_nil
    end
  end

  describe '.store_campaign' do
    it 'stores the campaign id and name' do
      described_class.store_campaign(123, 'Annual Fund')
      expect(described_class.campaign).to eq(LglSetting::Campaign.new(123, 'Annual Fund'))
    end

    it 'stamps gifts_since with the moment of the first choice' do
      travel_to(Time.zone.local(2026, 10, 15, 9, 30, 0)) { described_class.store_campaign(123, 'Annual Fund') }
      expect(described_class.gifts_since).to eq(Time.zone.local(2026, 10, 15, 9, 30, 0))
    end

    it 'keeps the first gifts_since stamp when the campaign changes later' do
      travel_to(Time.zone.local(2026, 10, 15, 9, 30, 0)) { described_class.store_campaign(123, 'Annual Fund') }
      travel_to(Time.zone.local(2026, 11, 1, 12, 0, 0)) { described_class.store_campaign(456, 'Capital Fund') }
      expect(described_class.campaign).to eq(LglSetting::Campaign.new(456, 'Capital Fund'))
      expect(described_class.gifts_since).to eq(Time.zone.local(2026, 10, 15, 9, 30, 0))
    end
  end

  describe '.gifts_since' do
    it 'is nil before a campaign has been chosen' do
      expect(described_class.gifts_since).to be_nil
    end
  end

  describe 'season appeal ids' do
    it 'round-trips an appeal id per season as an integer' do
      described_class.store_season_appeal_id(2026, 789)
      expect(described_class.season_appeal_id(2026)).to eq(789)
      expect(described_class.season_appeal_id(2025)).to be_nil
    end
  end
end
