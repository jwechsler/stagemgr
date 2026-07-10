require 'rails_helper'

RSpec.describe SyncMembershipMyEmmaJob do
  let(:offer) { FactoryBot.create(:membership_offer, myemma_group: 'GRP1') }
  let(:address) { FactoryBot.create(:address) }
  let(:membership) { FactoryBot.create(:membership, membership_offer: offer, address: address) }

  let(:member) { instance_double(MyEmma::Member).as_null_object }

  before { allow(MyEmma).to receive(:disabled?).and_return(false) }

  describe 'adding an active membership' do
    it 'upserts the member with the address fields into the offer group' do
      allow(MyEmma::Member).to receive(:find_by_email).with(address.email).and_return(nil)
      allow(MyEmma::Member).to receive(:new).and_return(member)

      described_class.perform(membership.id)

      expect(member).to have_received(:name_first=).with(address.first_name)
      expect(member).to have_received(:name_last=).with(address.last_name)
      expect(member).to have_received(:email=).with(address.email)
      expect(member).to have_received(:address=).with(address.line1)
      expect(member).to have_received(:city=).with(address.city)
      expect(member).to have_received(:state=).with(address.state)
      expect(member).to have_received(:postal_code=).with(address.zipcode)
      expect(member).to have_received(:save).with(['GRP1'])
    end

    it 'reuses an existing MyEmma member found by email' do
      allow(MyEmma::Member).to receive(:find_by_email).with(address.email).and_return(member)

      described_class.perform(membership.id)

      expect(MyEmma::Member).not_to receive(:new)
      expect(member).to have_received(:save).with(['GRP1'])
    end

    it 'propagates API errors so they land in the Resque failed queue' do
      allow(MyEmma::Member).to receive(:find_by_email).and_return(member)
      allow(member).to receive(:save).and_raise('MyEmma error: boom')

      expect { described_class.perform(membership.id) }.to raise_error(/MyEmma error/)
    end
  end

  describe 'removing an inactive membership' do
    let(:group) { instance_double(MyEmma::Group, remove_members: true) }

    before { membership.update_column(:status, Membership::CANCELED) }

    it 'removes the member from the offer group' do
      allow(MyEmma::Member).to receive(:find_by_email).with(address.email).and_return(member)
      allow(MyEmma::Group).to receive(:find).with('GRP1').and_return(group)

      described_class.perform(membership.id)

      expect(group).to have_received(:remove_members).with(member)
    end

    it 'does nothing when the address is still a current member elsewhere' do
      allow_any_instance_of(Address).to receive(:is_current_member?).and_return(true)

      expect(MyEmma::Member).not_to receive(:find_by_email)

      described_class.perform(membership.id)
    end

    it 'does nothing when MyEmma has no member for the email' do
      allow(MyEmma::Member).to receive(:find_by_email).with(address.email).and_return(nil)

      expect(MyEmma::Group).not_to receive(:find)

      described_class.perform(membership.id)
    end
  end

  describe 'guards' do
    it 'does nothing when the offer has no MyEmma group' do
      offer.update_column(:myemma_group, nil)

      expect(MyEmma::Member).not_to receive(:find_by_email)

      described_class.perform(membership.id)
    end

    it 'does nothing when the address has no email' do
      address.update_column(:email, '')

      expect(MyEmma::Member).not_to receive(:find_by_email)

      described_class.perform(membership.id)
    end

    it 'does nothing for a vanished membership id' do
      expect { described_class.perform(-1) }.not_to raise_error
    end

    it 'does nothing when MyEmma is disabled' do
      allow(MyEmma).to receive(:disabled?).and_return(true)

      expect(MyEmma::Member).not_to receive(:find_by_email)

      described_class.perform(membership.id)
    end
  end
end
