require 'rails_helper'

RSpec.describe Admin::FlexPassOffersController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:theater) { FactoryBot.create(:theater) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe 'GET #index' do
    render_views

    let!(:active_offer) { FactoryBot.create(:flex_pass_offer, name: 'Live Pass', theater: theater) }
    let!(:inactive_offer) do
      # on_sale_to_public must also be false: set_public_sale_by_active
      # re-enables active from on_sale_to_public otherwise.
      FactoryBot.create(:flex_pass_offer, name: 'Retired Pass', theater: theater,
                                          active: false, on_sale_to_public: false)
    end

    def datatable_params(status_scope: nil)
      columns = %w[offer price qty public restrictions actions]
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

      expect(response.body).to include('active_flex_pass_offer_listing')
      expect(response.body).to include('inactive_flex_pass_offer_listing')
      expect(response.body).to include('status_scope=active')
      expect(response.body).to include('status_scope=inactive')
    end

    context 'as JSON' do
      def listed_names
        response.parsed_body['data'].pluck('offer').join
      end

      def listed_actions
        response.parsed_body['data'].pluck('actions').join
      end

      it 'returns only active offers for status_scope=active' do
        get :index, params: datatable_params(status_scope: 'active'), format: :json

        expect(listed_names).to include('Live Pass')
        expect(listed_names).not_to include('Retired Pass')
        expect(listed_actions).to include('Create Order')
      end

      it 'returns only inactive offers for status_scope=inactive' do
        get :index, params: datatable_params(status_scope: 'inactive'), format: :json

        expect(listed_names).to include('Retired Pass')
        expect(listed_names).not_to include('Live Pass')
      end

      it 'omits the Create Order button for inactive offers' do
        get :index, params: datatable_params(status_scope: 'inactive'), format: :json

        expect(listed_actions).not_to include('Create Order')
      end

      it 'returns all offers when status_scope is omitted' do
        get :index, params: datatable_params, format: :json

        expect(listed_names).to include('Live Pass', 'Retired Pass')
      end
    end
  end

  describe 'POST #create' do
    context 'with decimal values for currency fields' do
      let(:valid_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: '99.99',
            facility_fee: '2.50',
            spiff: '1.75',
            flat_payout: '5.25',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'creates a flex pass offer with decimal values' do
        expect do
          post :create, params: valid_params
        end.to change(FlexPassOffer, :count).by(1)

        offer = FlexPassOffer.last
        expect(offer.price).to eq(99.99)
        expect(offer.facility_fee).to eq(2.50)
        expect(offer.spiff).to eq(1.75)
        expect(offer.flat_payout).to eq(5.25)
      end

      it 'redirects to the flex pass offers index' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_flex_pass_offers_path)
      end
    end

    context 'with invalid values for currency fields' do
      let(:invalid_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: 'not a number',
            facility_fee: 'invalid',
            spiff: 'abc',
            flat_payout: 'xyz',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'does not create a flex pass offer' do
        expect do
          post :create, params: invalid_params
        end.not_to change(FlexPassOffer, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end

    context 'with negative values for currency fields' do
      let(:negative_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: '-10',
            facility_fee: '-2.50',
            spiff: '-1.75',
            flat_payout: '-5.25',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'does not create a flex pass offer' do
        expect do
          post :create, params: negative_params
        end.not_to change(FlexPassOffer, :count)
      end

      it 'renders the new template' do
        post :create, params: negative_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let(:flex_pass_offer) { FactoryBot.create(:flex_pass_offer, theater: theater) }

    context 'with valid decimal values' do
      let(:update_params) do
        {
          id: flex_pass_offer.id,
          flex_pass_offer: {
            price: '149.99',
            facility_fee: '3.50',
            spiff: '2.25',
            flat_payout: '7.75'
          }
        }
      end

      it 'updates the flex pass offer with decimal values' do
        patch :update, params: update_params

        flex_pass_offer.reload
        expect(flex_pass_offer.price).to eq(149.99)
        expect(flex_pass_offer.facility_fee).to eq(3.50)
        expect(flex_pass_offer.spiff).to eq(2.25)
        expect(flex_pass_offer.flat_payout).to eq(7.75)
      end

      it 'redirects to the flex pass offer' do
        patch :update, params: update_params
        expect(response).to redirect_to(admin_flex_pass_offer_path(flex_pass_offer))
      end
    end

    context 'with invalid values' do
      let(:invalid_update_params) do
        {
          id: flex_pass_offer.id,
          flex_pass_offer: {
            price: 'invalid'
          }
        }
      end

      it 'does not update the flex pass offer' do
        original_price = flex_pass_offer.price
        patch :update, params: invalid_update_params

        flex_pass_offer.reload
        expect(flex_pass_offer.price).to eq(original_price)
      end

      it 'renders the edit template' do
        patch :update, params: invalid_update_params
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'GET #search' do
    let!(:active_offer) { FactoryBot.create(:flex_pass_offer, name: 'Wit Pass', theater: theater) }
    let!(:inactive_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Wit Retired', theater: theater, active: false,
                                          on_sale_to_public: false)
    end

    it 'returns matching active offers with tag groups' do
      active_offer.flex_pass_offer_tags.create!(name: 'Witty')
      get :search, params: { q: 'wit' }, format: :json

      labels = response.parsed_body.pluck('label').join
      expect(labels).to include('Wit Pass', 'All offers tagged Witty')
      expect(labels).not_to include('Wit Retired')
    end

    it 'returns a theater group for a theater-name match' do
      get :search, params: { q: theater.name }, format: :json
      expect(response.parsed_body.pluck('group_key')).to include("theater:#{theater.id}")
    end
  end

  describe 'GET #resolve_group' do
    let!(:restricted_offer) { FactoryBot.create(:flex_pass_offer, name: 'Wit Pass', theater: theater) }
    let!(:excluding_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Roving Pass', theater: theater, exclude_theater: true)
    end

    it 'expands a theater group into restricted-to-theater offers only' do
      get :resolve_group, params: { group_key: "theater:#{theater.id}" }, format: :json
      names = response.parsed_body.pluck('name')
      expect(names).to contain_exactly('Wit Pass')
    end
  end

  describe 'strong parameters' do
    it 'permits the currency fields' do
      ActionController::Parameters.new({
                                         flex_pass_offer: {
                                           price: '99.99',
                                           facility_fee: '2.50',
                                           spiff: '1.75',
                                           flat_payout: '5.25',
                                           other_param: 'should be filtered'
                                         }
                                       })

      # We need to test that the controller permits these params
      # This is a bit tricky to test directly, so we'll create the offer
      # and verify the values were set
      post :create, params: {
        flex_pass_offer: {
          name: 'Test Pass',
          theater_id: theater.id,
          price: '99.99',
          facility_fee: '2.50',
          spiff: '1.75',
          flat_payout: '5.25',
          number_of_tickets: '10',
          active: 'true',
          months_till_expiration: '12',
          use_ticket_class_code: 'PASS'
        }
      }

      offer = FlexPassOffer.last
      expect(offer.price).to eq(99.99)
      expect(offer.facility_fee).to eq(2.50)
      expect(offer.spiff).to eq(1.75)
      expect(offer.flat_payout).to eq(5.25)
    end
  end
end
