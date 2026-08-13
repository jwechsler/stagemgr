require 'rails_helper'

RSpec.describe Admin::AddressesController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe '#update' do
    it 'truly merges when an edit makes the record match an existing one' do
      keeper = FactoryBot.create(:address, full_name: 'Merged Patron', email: 'merged@example.com')
      edited = FactoryBot.create(:address, full_name: 'Merged Patron-typo', email: 'merged@example.com')
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, address: edited)

      put :update, params: { id: edited.id, address: { full_name: 'Merged Patron' } }

      # The old behavior copied fields onto the match but abandoned the edited
      # record with all of its orders, leaving a permanent duplicate.
      expect(order.reload.address_id).to eq(keeper.id)
      expect(Address.exists?(edited.id)).to be(false)
    end

    it 'updates normally when no duplicate exists' do
      address = FactoryBot.create(:address, full_name: 'Solo Patron', email: 'solo@example.com')

      put :update, params: { id: address.id, address: { full_name: 'Solo Patron Jr' } }

      expect(address.reload.full_name).to eq('Solo Patron Jr')
    end
  end
end
