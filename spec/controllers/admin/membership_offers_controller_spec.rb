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

  describe 'GET #index' do
    render_views

    def datatable_params(status_scope: nil)
      columns = %w[name on_sale membership_type status]
                .each_with_index.to_h do |col, i|
        [i.to_s, { data: col, searchable: 'true', orderable: 'true',
                   search: { value: '', regex: 'false' } }]
      end
      params = { draw: '1', start: '0', length: '25',
                 search: { value: '', regex: 'false' }, columns: columns }
      params[:status_scope] = status_scope if status_scope
      params
    end

    it 'renders Active and Inactive tabs, each with its own scoped table' do
      get :index

      expect(response.body).to include('active_membership_offer_listing')
      expect(response.body).to include('inactive_membership_offer_listing')
      expect(response.body).to include('status_scope=active')
      expect(response.body).to include('status_scope=inactive')
    end

    context 'as JSON' do
      def listed_names
        response.parsed_body['data'].pluck('name').join
      end

      def listed_actions
        response.parsed_body['data'].pluck('status').join
      end

      it 'returns only Active offers for status_scope=active' do
        get :index, params: datatable_params(status_scope: 'active'), format: :json

        expect(listed_names).to include('Gold Membership')
        expect(listed_names).not_to include('Gold Legacy')
        expect(listed_actions).to include('Create Order')
      end

      it 'returns only Inactive offers for status_scope=inactive' do
        get :index, params: datatable_params(status_scope: 'inactive'), format: :json

        expect(listed_names).to include('Gold Legacy')
        expect(listed_names).not_to include('Gold Membership')
      end

      it 'omits the sales-action button for inactive offers' do
        get :index, params: datatable_params(status_scope: 'inactive'), format: :json

        expect(listed_actions).not_to include('Create Order', 'Issue Pass')
      end

      it 'returns all offers when status_scope is omitted' do
        get :index, params: datatable_params, format: :json

        expect(listed_names).to include('Gold Membership', 'Gold Legacy')
      end
    end
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
