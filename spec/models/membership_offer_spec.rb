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

  describe '#usage_date_range' do
    it 'returns [nil, nil] for an offer with neither payments nor memberships' do
      offer = FactoryBot.create(:membership_offer, :timed)

      expect(offer.usage_date_range).to eq([nil, nil])
    end

    it 'spans from the earliest membership window to today for a payment-less timed offer' do
      offer = FactoryBot.create(:membership_offer, :timed)
      FactoryBot.create(:library_pass, membership_offer: offer, member_since: Date.new(2026, 4, 5))

      expect(offer.usage_date_range).to eq([Date.new(2026, 4, 5), Date.current])
    end

    it 'ignores Pending memberships when widening the range' do
      offer = FactoryBot.create(:membership_offer, :timed)
      FactoryBot.create(:library_pass, membership_offer: offer, member_since: Date.new(2026, 4, 5),
                                       status: Membership::PENDING)

      expect(offer.usage_date_range).to eq([nil, nil])
    end

    it 'widens a payment-derived range with earlier membership windows' do
      offer = FactoryBot.create(:membership_offer)
      order = FactoryBot.create(:membership_order)
      order.membership_line_item.update!(membership_offer: offer)
      order.membership.update!(membership_offer: offer, member_since: Date.new(2026, 2, 1))
      order.payments.each { |payment| payment.update!(processed_on: Time.zone.local(2026, 3, 15, 12, 0, 0)) }

      first, last = offer.usage_date_range
      expect(first).to eq(Date.new(2026, 2, 1))
      expect(last).to eq(Date.current)
    end
  end

  describe 'MyEmma group re-sync' do
    let!(:offer) { FactoryBot.create(:membership_offer, myemma_group: 'OLD') }

    context 'when MyEmma is enabled' do
      before { allow(MyEmma).to receive(:disabled?).and_return(false) }

      it 'enqueues a re-sync when the group changes' do
        expect(Resque).to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, offer.id)

        offer.update!(myemma_group: 'NEW')
      end

      it 'does not enqueue when another attribute changes' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        offer.update!(name: 'Renamed Offer')
      end

      it 'does not enqueue when the group is blanked' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        offer.update!(myemma_group: '')
      end

      it 'does not enqueue on create' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        FactoryBot.create(:membership_offer, name: 'Fresh', myemma_group: 'GRP')
      end
    end

    it 'does not enqueue when MyEmma is disabled (test default)' do
      expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

      offer.update!(myemma_group: 'NEW')
    end
  end
end
