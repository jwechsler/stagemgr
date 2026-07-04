require 'rails_helper'

RSpec.describe Seat do
  let(:seat_map) { FactoryBot.create(:seat_map, seat_count: 0) }

  describe 'zone normalization and validation' do
    it 'defaults a blank zone to "A" (factory uses "")' do
      seat = FactoryBot.create(:seat, seat_map: seat_map, zone: '')
      expect(seat.zone).to eq('A')
    end

    it 'defaults a nil zone to "A"' do
      seat = FactoryBot.create(:seat, seat_map: seat_map, zone: nil)
      expect(seat.zone).to eq('A')
    end

    it 'strips and upcases the zone' do
      seat = FactoryBot.create(:seat, seat_map: seat_map, zone: ' b2 ')
      expect(seat.zone).to eq('B2')
    end

    it 'accepts 1-2 character A-Z/0-9 zones' do
      expect(FactoryBot.build(:seat, seat_map: seat_map, zone: 'A')).to be_valid
      expect(FactoryBot.build(:seat, seat_map: seat_map, zone: 'Z9')).to be_valid
    end

    it 'rejects the wildcard "*" on seats' do
      seat = FactoryBot.build(:seat, seat_map: seat_map, zone: '*')
      expect(seat).not_to be_valid
      expect(seat.errors[:zone]).to be_present
    end

    it 'rejects zones longer than 2 characters' do
      expect(FactoryBot.build(:seat, seat_map: seat_map, zone: 'ABC')).not_to be_valid
    end

    it 'rejects non-alphanumeric zones' do
      expect(FactoryBot.build(:seat, seat_map: seat_map, zone: 'A-')).not_to be_valid
    end
  end

  describe 'legacy compatibility' do
    it 'matches a wildcard ticket class regardless of zone (backfill regression)' do
      seat = FactoryBot.create(:seat, seat_map: seat_map) # factory zone '' -> normalized 'A'
      legacy_class = FactoryBot.create(:ticket_class)     # zone_id defaults to '*'
      expect(legacy_class.sellable_for_zone?(seat.zone)).to be true
    end
  end
end
