require 'rails_helper'

RSpec.describe DefaultTicketClass do
  it 'should create an identical copy of itself as an associated ticket class when a production is created' do
    default_ticket_class = FactoryBot.create(:default_ticket_class, class_code: 'TEST')
    default_ticket_class.save
    production = FactoryBot.create(:production)
    ticket_class = production.ticket_classes.select { |tc| tc.class_code == default_ticket_class.class_code }.first
    default_attributes = default_ticket_class.to_hash
    default_attributes.keys.each do |key|
      expect(ticket_class.attributes).to include(key)
      expect(ticket_class[key]).to eq(default_attributes[key])
    end
  end

  describe '#destroy' do
    it 'destroys a default ticket class not referenced by any offer' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'UNUSED')
      expect(dtc.destroy).to be_truthy
      expect(DefaultTicketClass.exists?(dtc.id)).to eq(false)
    end

    it 'refuses to destroy when a FlexPassOffer references the class code and names it in the error' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'FLEXREF')
      FactoryBot.create(:flex_pass_offer, name: 'Seasonal Flex', use_ticket_class_code: 'FLEXREF')
      expect(dtc.destroy).to eq(false)
      msg = dtc.errors[:base].join
      expect(msg).to include("flex pass offer 'Seasonal Flex'")
      expect(msg).to include("'FLEXREF'")
      expect(DefaultTicketClass.exists?(dtc.id)).to eq(true)
    end

    it 'refuses to destroy when a MembershipOffer references the class code and names it in the error' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'MEMBREF')
      FactoryBot.create(:membership_offer, name: 'Wit Membership', use_ticket_class_code: 'MEMBREF')
      expect(dtc.destroy).to eq(false)
      msg = dtc.errors[:base].join
      expect(msg).to include("membership offer 'Wit Membership'")
      expect(msg).to include("'MEMBREF'")
      expect(DefaultTicketClass.exists?(dtc.id)).to eq(true)
    end

    it 'refuses to destroy when a MembershipOffer references the code as use_member_friend_code' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'FRIENDREF')
      FactoryBot.create(:membership_offer, name: 'Buddy Membership', use_ticket_class_code: 'OTHER',
                                           use_member_friend_code: 'FRIENDREF')
      expect(dtc.destroy).to eq(false)
      msg = dtc.errors[:base].join
      expect(msg).to include("membership offer 'Buddy Membership'")
      expect(msg).to include("'FRIENDREF'")
      expect(DefaultTicketClass.exists?(dtc.id)).to eq(true)
    end

    it 'lists a membership offer only once when it references the code in both columns' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'BOTHREF')
      FactoryBot.create(:membership_offer, name: 'Double-Ref Membership', use_ticket_class_code: 'BOTHREF',
                                           use_member_friend_code: 'BOTHREF')
      expect(dtc.destroy).to eq(false)
      msg = dtc.errors[:base].join
      expect(msg.scan("'Double-Ref Membership'").size).to eq(1)
      expect(msg).to include("membership offer 'Double-Ref Membership'")
    end

    it 'names multiple offers of the same type when several reference the class code' do
      dtc = FactoryBot.create(:default_ticket_class, class_code: 'MULTI')
      FactoryBot.create(:membership_offer, name: 'Alpha Membership', use_ticket_class_code: 'MULTI')
      FactoryBot.create(:membership_offer, name: 'Beta Membership', use_ticket_class_code: 'MULTI')
      expect(dtc.destroy).to eq(false)
      msg = dtc.errors[:base].join
      expect(msg).to include('membership offers')
      expect(msg).to include("'Alpha Membership'")
      expect(msg).to include("'Beta Membership'")
    end
  end
end
