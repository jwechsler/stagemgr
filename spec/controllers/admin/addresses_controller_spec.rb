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

    it 'offers no Issue Membership button; memberships come from orders or Issue Pass' do
      get :show, params: { id: address.id }

      expect(response.body).not_to include('Issue Membership', new_admin_membership_path)
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

  describe '#lgl_sync' do
    let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
    let(:address) { FactoryBot.create(:address) }

    before { allow(Resque).to receive(:enqueue) }

    context 'when LGL is enabled' do
      before { allow(Lgl).to receive(:enabled?).and_return(true) }

      it 'queues a manual sync and returns to the customer page' do
        post :lgl_sync, params: { id: address.id }

        expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, address.id, 'manual')
        expect(response).to redirect_to(admin_address_path(address))
        expect(flash[:notice]).to eq('Queued a sync with Little Green Light')
      end

      it 'refuses a box office user without queuing' do
        box_office = FactoryBot.create(:user, is_box_office_user: true)
        allow(controller).to receive(:current_user).and_return(box_office)

        post :lgl_sync, params: { id: address.id }

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(root_path)
      end

      it 'links the LGL ID to the configured account and shows the sync button' do
        address.set_lgl_id!(4321)
        allow(Lgl).to receive(:constituent_url).with('4321')
                                               .and_return('https://house.littlegreenlight.com/constituents/4321')

        get :show, params: { id: address.id }

        expect(response.body).to include('href="https://house.littlegreenlight.com/constituents/4321"')
        expect(response.body).to include('Re-sync with LGL', lgl_sync_admin_address_path(address))
      end

      it 'shows the LGL ID as plain text when no LGL web URL is configured' do
        address.set_lgl_id!(4321)

        get :show, params: { id: address.id }

        expect(response.body).to include('4321')
        expect(response.body).not_to include('littlegreenlight.com')
      end

      it 'shows an unlinked address and its review reason' do
        address.lgl_review!('2 LGL constituents share this email')

        get :show, params: { id: address.id }

        expect(response.body).to include('not linked', 'Link to LGL', '2 LGL constituents share this email')
      end
    end

    context 'when LGL is disabled' do
      it 'redirects with an alert and queues nothing' do
        post :lgl_sync, params: { id: address.id }

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(admin_address_path(address))
        expect(flash[:alert]).to be_present
      end

      it 'shows no LGL line on the customer page' do
        get :show, params: { id: address.id }

        expect(response.body).not_to include('Link to LGL')
      end
    end
  end
end
