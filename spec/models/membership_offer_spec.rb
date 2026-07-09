require 'rails_helper'

RSpec.describe MembershipOffer do
  it 'defaults membership_type to production' do
    expect(MembershipOffer.new.membership_type).to eq(MembershipOffer::PRODUCTION)
  end

  it 'rejects a membership_type outside the allowed set' do
    offer = FactoryBot.build(:membership_offer, membership_type: 'bogus')

    expect(offer).not_to be_valid
    expect(offer.errors[:membership_type]).to be_present
  end

  it 'does not require a price_id for an active timed offer' do
    offer = FactoryBot.build(:membership_offer, :timed, status: MembershipOffer::ACTIVE, price_id: nil)

    expect(offer).to be_valid
  end

  it 'still requires a price_id for an active production offer' do
    offer = FactoryBot.build(:membership_offer, status: MembershipOffer::ACTIVE, price_id: nil)

    expect(offer).not_to be_valid
    expect(offer.errors[:price_id]).to be_present
  end

  it 'is never on sale to the public when timed, even if on_sale is set' do
    offer = FactoryBot.build(:membership_offer, :timed)
    offer.on_sale = true

    expect(offer.on_sale_to_public?).to be false
  end

  it 'forces on_sale to false when a timed offer is saved' do
    offer = FactoryBot.create(:membership_offer, :timed, status: MembershipOffer::ACTIVE)
    offer.on_sale = true
    offer.save!

    expect(offer.reload.on_sale).to be_falsey
  end
end
