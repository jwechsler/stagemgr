require 'rails_helper'

RSpec.describe Admin::AddressesController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe '#show' do
    let(:membership_order) { FactoryBot.create(:membership_order) }
    let(:address) { membership_order.address }
    let(:membership) { membership_order.membership_line_item.membership }

    it 'links each active member code to its membership order' do
      get :show, params: { id: address.id }

      expect(response.body).to include('Active Memberships')
      expect(response.body).to include(
        %(<a href="#{admin_membership_order_path(membership_order)}">#{membership.member_code}</a>)
      )
    end

    it 'links an active membership issued without an order to the membership itself' do
      issued = FactoryBot.create(:membership, address: address, member_code: 'NOORDER1',
                                              membership_offer: membership.membership_offer)

      get :show, params: { id: address.id }

      expect(response.body).to include(%(<a href="#{admin_membership_path(issued)}">NOORDER1</a>))
    end
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
