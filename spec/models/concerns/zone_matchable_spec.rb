require 'rails_helper'

RSpec.describe ZoneMatchable do
  describe '.match?' do
    it 'matches the wildcard class zone against any seat zone' do
      expect(described_class.match?('*', 'A')).to be true
      expect(described_class.match?('*', 'Z9')).to be true
    end

    it 'matches identical zones' do
      expect(described_class.match?('A', 'A')).to be true
      expect(described_class.match?('B2', 'B2')).to be true
    end

    it 'rejects differing zones' do
      expect(described_class.match?('A', 'B')).to be false
      expect(described_class.match?('B2', 'B')).to be false
    end

    it 'never treats a seat-side "*" as a wildcard' do
      expect(described_class.match?('A', '*')).to be false
    end
  end

  describe 'formats' do
    it 'accepts 1-2 char A-Z/0-9 seat zones and rejects the wildcard' do
      expect('A').to match(ZoneMatchable::SEAT_ZONE_FORMAT)
      expect('Z9').to match(ZoneMatchable::SEAT_ZONE_FORMAT)
      expect('*').not_to match(ZoneMatchable::SEAT_ZONE_FORMAT)
      expect('ABC').not_to match(ZoneMatchable::SEAT_ZONE_FORMAT)
      expect('a').not_to match(ZoneMatchable::SEAT_ZONE_FORMAT)
    end

    it 'accepts the wildcard for class zones' do
      expect('*').to match(ZoneMatchable::CLASS_ZONE_FORMAT)
      expect('B2').to match(ZoneMatchable::CLASS_ZONE_FORMAT)
      expect('**').not_to match(ZoneMatchable::CLASS_ZONE_FORMAT)
      expect('ABC').not_to match(ZoneMatchable::CLASS_ZONE_FORMAT)
    end
  end
end
