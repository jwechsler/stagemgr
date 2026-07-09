require 'rails_helper'

RSpec.describe Admin::MembershipsController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:address)    { FactoryBot.create(:address) }

  let!(:timed_offer) do
    FactoryBot.create(:membership_offer, name: 'Library Pass', membership_type: MembershipOffer::TIMED,
                                         price_id: nil)
  end

  let!(:membership) do
    FactoryBot.create(:membership, address: address, membership_offer: timed_offer, member_code: 'TW-LIB01')
  end

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe 'GET #index' do
    it 'lists memberships' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(membership.member_code)
    end
  end

  describe 'GET #show' do
    it 'renders the membership' do
      get :show, params: { id: membership.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(membership.member_code)
    end
  end

  describe 'GET #new' do
    it 'renders the new form' do
      get :new
      expect(response).to have_http_status(:ok)
    end

    it 'prefills the address and offer from params' do
      get :new, params: { address_id: address.id, membership_offer_id: timed_offer.id }

      expect(assigns(:membership).address_id).to eq(address.id)
      expect(assigns(:membership).membership_offer_id).to eq(timed_offer.id)
      expect(assigns(:membership).status).to eq(Membership::ACTIVE)
      expect(assigns(:membership).member_since).to eq(Date.today)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      { membership: { address_id: address.id, membership_offer_id: timed_offer.id, status: Membership::ACTIVE,
                      member_since: Date.today, preferred_seating: Membership::BEST_AVAILABLE } }
    end

    it 'creates an active membership with no order' do
      expect do
        post :create, params: valid_params
      end.to change(Membership, :count).by(1)

      created = Membership.last
      expect(created.status).to eq(Membership::ACTIVE)
      expect(created.address).to eq(address)
      expect(created.member_code).to be_present
      expect(created.membership_order).to be_nil
    end

    it 'redirects to the membership' do
      post :create, params: valid_params
      expect(response).to redirect_to(admin_membership_path(Membership.last))
    end

    context 'without an address' do
      let(:invalid_params) do
        { membership: { membership_offer_id: timed_offer.id, status: Membership::ACTIVE,
                        member_since: Date.today } }
      end

      it 'does not create the membership' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Membership, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    it 'allows changing status to Canceled' do
      patch :update, params: { id: membership.id, membership: { status: Membership::CANCELED } }
      expect(membership.reload.status).to eq(Membership::CANCELED)
    end

    it 'redirects to the membership' do
      patch :update, params: { id: membership.id, membership: { status: Membership::CANCELED } }
      expect(response).to redirect_to(admin_membership_path(membership))
    end
  end
end
