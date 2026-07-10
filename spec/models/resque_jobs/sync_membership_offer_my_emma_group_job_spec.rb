require 'rails_helper'

RSpec.describe SyncMembershipOfferMyEmmaGroupJob do
  let(:offer) { FactoryBot.create(:membership_offer, myemma_group: 'GRP1') }

  before { allow(MyEmma).to receive(:disabled?).and_return(false) }

  it 'fans out one membership sync per active membership only' do
    active = FactoryBot.create(:membership, membership_offer: offer)
    canceled = FactoryBot.create(:membership, membership_offer: offer, status: Membership::CANCELED,
                                              member_code: 'TESTMEM2')

    expect(Resque).to receive(:enqueue).with(SyncMembershipMyEmmaJob, active.id)
    expect(Resque).not_to receive(:enqueue).with(SyncMembershipMyEmmaJob, canceled.id)

    described_class.perform(offer.id)
  end

  it 'does nothing when the offer has no MyEmma group' do
    offer.update_column(:myemma_group, '')
    FactoryBot.create(:membership, membership_offer: offer)

    expect(Resque).not_to receive(:enqueue)

    described_class.perform(offer.id)
  end

  it 'does nothing for a vanished offer id' do
    expect(Resque).not_to receive(:enqueue)
    expect { described_class.perform(-1) }.not_to raise_error
  end

  it 'does nothing when MyEmma is disabled' do
    allow(MyEmma).to receive(:disabled?).and_return(true)
    FactoryBot.create(:membership, membership_offer: offer)

    expect(Resque).not_to receive(:enqueue)

    described_class.perform(offer.id)
  end
end
