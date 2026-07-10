require 'rails_helper'

RSpec.describe Admin::MembershipOffersController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }

  let!(:active_offer) { FactoryBot.create(:membership_offer, name: 'Gold Membership') }
  let!(:inactive_offer) do
    FactoryBot.create(:membership_offer, name: 'Gold Legacy', status: MembershipOffer::INACTIVE)
  end

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe 'GET #search' do
    it 'returns matching active offers with tag groups' do
      active_offer.membership_offer_tags.create!(name: 'Golden Circle')
      get :search, params: { q: 'gold' }, format: :json

      labels = response.parsed_body.pluck('label').join
      expect(labels).to include('Gold Membership', 'All offers tagged Golden Circle')
      expect(labels).not_to include('Gold Legacy')
    end
  end

  describe 'GET #resolve_group' do
    it 'expands a tag group into active offers only' do
      active_offer.membership_offer_tags.create!(name: 'Premium')
      inactive_offer.membership_offer_tags.create!(name: 'Premium')

      get :resolve_group, params: { group_key: 'tag:premium' }, format: :json
      expect(response.parsed_body.pluck('name')).to contain_exactly('Gold Membership')
    end
  end

  describe 'POST #create' do
    it 'permits membership_type' do
      expect do
        post :create, params: { membership_offer: {
          name: 'Library Pass', use_ticket_class_code: 'PASS', tickets_per_performance: 1,
          membership_type: MembershipOffer::TIMED
        } }
      end.to change(MembershipOffer, :count).by(1)

      expect(MembershipOffer.last.membership_type).to eq(MembershipOffer::TIMED)
    end
  end

  describe 'PATCH #update' do
    it 'permits membership_type' do
      patch :update, params: { id: active_offer.id, membership_offer: { membership_type: MembershipOffer::TIMED } }

      expect(active_offer.reload.membership_type).to eq(MembershipOffer::TIMED)
    end
  end
end
