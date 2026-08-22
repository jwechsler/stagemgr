require 'rails_helper'

RSpec.describe DefaultTicketClass, type: :model do
  describe 'zone_id' do
    it 'defaults to the wildcard zone' do
      default_class = FactoryBot.create(:default_ticket_class)

      expect(default_class.reload.zone_id).to eq(ZoneMatchable::WILDCARD)
    end

    it 'upcases and strips a supplied zone' do
      default_class = FactoryBot.create(:default_ticket_class)

      default_class.update!(zone_id: ' b1 ')

      expect(default_class.reload.zone_id).to eq('B1')
    end

    it 'falls back to the wildcard when the zone is blanked' do
      default_class = FactoryBot.create(:default_ticket_class, zone_id: 'B')

      default_class.update!(zone_id: '')

      expect(default_class.reload.zone_id).to eq(ZoneMatchable::WILDCARD)
    end

    it 'rejects a zone outside the class zone format' do
      default_class = FactoryBot.build(:default_ticket_class, zone_id: 'B-')

      expect(default_class).not_to be_valid
      expect(default_class.errors[:zone_id]).to include('must be "*" or 1-2 characters A-Z or 0-9')
    end
  end

  describe '#to_hash' do
    it 'carries zone_id onto ticket classes built from the default' do
      default_class = FactoryBot.create(:default_ticket_class, zone_id: 'C2')

      expect(default_class.to_hash['zone_id']).to eq('C2')
    end

    it 'gives new productions the default zone via assign_default_ticket_classes' do
      FactoryBot.create(:default_ticket_class, class_code: 'ZONED', zone_id: 'C2')

      production = FactoryBot.create(:production)

      expect(production.ticket_classes.find_by(class_code: 'ZONED').zone_id).to eq('C2')
    end
  end
end
