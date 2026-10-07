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
      # on_sale_to_public must also be false: sync_active_with_public_sale
      # activates a new offer that is on public sale.
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

  describe 'GET #show' do
    render_views

    let(:offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Five Show Pass', price: 25, number_of_tickets: 5,
                                          flat_payout: 10, facility_fee: 3, spiff: 1,
                                          code_prefix: 'FLAT', months_till_expiration: 2)
    end

    it 'shows status labels, uncapped uses, expiry and the code format' do
      get :show, params: { id: offer.id }

      expect(response.body).to include('>Active<', '>On sale to public<')
      expect(response.body).not_to include('>Festival pass<', '>Autofulfill<')
      expect(response.body.scan('No limit').size).to eq(2)
      expect(response.body).to include('2 months after purchase')
      expect(response.body).to include('FLATXXXXXX')
    end

    it 'shows the payout figures with their hints and the recoverable amount' do
      get :show, params: { id: offer.id }

      FlexPassOfferDecorator::PAYOUT_HINTS.each_value do |hint|
        expect(response.body).to include(ERB::Util.html_escape(hint))
      end
      expect(response.body).to include('Recoverable at expiry if unused:')
      expect(response.body).to include('$12.00')
    end

    it 'shows per-production and per-performance caps when set' do
      offer.update_columns(maximum_uses_per_production: 2, maximum_uses_per_performance: 1)

      get :show, params: { id: offer.id }

      expect(response.body).to include('2 tickets', '1 ticket')
      expect(response.body).not_to include('No limit')
    end

    context 'with theater restrictions' do
      it 'says Any theater when unrestricted' do
        get :show, params: { id: offer.id }
        expect(response.body).to include('Any theater')
      end

      it 'names the only theater' do
        offer.update_columns(theater_id: theater.id, exclude_theater: false)
        get :show, params: { id: offer.id }
        expect(response.body).to include(ERB::Util.html_escape("Only #{theater.name}"))
      end

      it 'names the excluded theater' do
        offer.update_columns(theater_id: theater.id, exclude_theater: true)
        get :show, params: { id: offer.id }
        expect(response.body).to include(ERB::Util.html_escape("All but #{theater.name}"))
      end
    end

    it 'links the public purchase page when on sale' do
      get :show, params: { id: offer.id }

      expect(response.body).to include(new_flex_pass_offer_order_url(offer))
      expect(response.body).not_to include('Box office only')
    end

    it 'says Box office only when not on public sale' do
      offer.update_columns(on_sale_to_public: false)

      get :show, params: { id: offer.id }

      expect(response.body).to include('Box office only')
      expect(response.body).not_to include(new_flex_pass_offer_order_url(offer))
    end

    it 'links the festival and labels a festival pass' do
      festival = FactoryBot.create(:festival)
      offer.update_columns(festival_id: festival.id)

      get :show, params: { id: offer.id }

      expect(response.body).to include('>Festival pass<')
      expect(response.body).to include(admin_festival_path(festival))
    end

    it 'links known autofulfill performances and flags unknown codes' do
      performance = FactoryBot.create(:performance)
      offer.update_columns(autofulfill_performance_codes: "#{performance.performance_code}, NOSUCHCODE",
                           maximum_uses_per_performance: 2)
      production = performance.production

      get :show, params: { id: offer.id }

      expect(response.body).to include('>Autofulfill<')
      expect(response.body).to include(admin_theater_production_performance_path(production.theater, production, performance))
      expect(response.body).to include(ERB::Util.html_escape(production.name))
      expect(response.body).to include('NOSUCHCODE', 'Unknown code')
      expect(response.body).to include('2 tickets each; 4 reserved per purchase')
    end

    it 'shows Edit and Create Order for an active offer' do
      get :show, params: { id: offer.id }

      expect(response.body).to include(edit_admin_flex_pass_offer_path(offer))
      expect(response.body).to include(new_admin_flex_pass_offer_order_path(offer))
    end

    it 'omits Create Order for an inactive offer' do
      offer.update_columns(active: false, on_sale_to_public: false)

      get :show, params: { id: offer.id }

      expect(response.body).to include('>Inactive<', edit_admin_flex_pass_offer_path(offer))
      expect(response.body).not_to include(new_admin_flex_pass_offer_order_path(offer))
    end

    it 'shows the empty state and the passes table source when nothing is sold' do
      get :show, params: { id: offer.id }

      expect(response.body).to include('No passes have been sold yet.')
      expect(response.body).to include('flex-pass-offer-passes-listing')
      # HAML emits single-quoted attributes; match either quote style.
      source = Regexp.escape(admin_flex_pass_offer_path(offer, format: :json))
      expect(response.body).to match(/data-source=['"]#{source}['"]/)
    end

    it 'shows usage counts once passes are sold' do
      allow(Resque).to receive(:enqueue_in)
      FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)

      get :show, params: { id: offer.id }

      expect(response.body).not_to include('No passes have been sold yet.')
      expect(response.body).to include('of 5 issued')
    end

    context 'as JSON' do
      def datatable_params
        columns = %w[code patron order purchased expires uses_remaining fulfillment]
                  .each_with_index.to_h do |col, i|
          [i.to_s, { data: col, searchable: 'true', orderable: 'true',
                     search: { value: '', regex: 'false' } }]
        end
        { id: offer.id, draw: '1', start: '0', length: '25',
          search: { value: '', regex: 'false' }, columns: columns,
          order: { '0' => { column: '4', dir: 'asc' } } }
      end

      it 'returns the outstanding passes only' do
        allow(Resque).to receive(:enqueue_in)
        outstanding = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass_line_item.flex_pass
        expired = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass_line_item.flex_pass
        expired.update_columns(expiration_date: Date.current - 1)

        get :show, params: datatable_params, format: :json

        rows = response.parsed_body['data']
        expect(rows.pluck('code')).to contain_exactly(outstanding.code)
        # ajax-datatables-rails stringifies every cell value.
        expect(rows.first['uses_remaining']).to eq('5')
        expect(response.parsed_body['recordsTotal']).to eq(1)
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

    context 'when returning to the screen the edit came from' do
      let(:params) { { id: flex_pass_offer.id, flex_pass_offer: { name: 'Renamed Pass' } } }

      it 'returns to the index when the edit came from the index' do
        patch :update, params: params.merge(return_to: 'index')
        expect(response).to redirect_to(admin_flex_pass_offers_path)
      end

      it 'returns to the show page when no return_to is given' do
        patch :update, params: params
        expect(response).to redirect_to(admin_flex_pass_offer_path(flex_pass_offer))
      end

      it 'ignores an unrecognised return_to rather than redirecting to it' do
        patch :update, params: params.merge(return_to: 'https://evil.example.com')
        expect(response).to redirect_to(admin_flex_pass_offer_path(flex_pass_offer))
      end
    end

    context 'GET #edit from the index' do
      render_views

      it 'carries return_to into the form' do
        get :edit, params: { id: flex_pass_offer.id, return_to: 'index' }
        expect(response.body).to include('name="return_to"').and include('value="index"')
      end
    end

    context 'when unchecking active on an offer that is on sale to the public' do
      it 'deactivates the offer and takes it off public sale' do
        patch :update, params: { id: flex_pass_offer.id,
                                 flex_pass_offer: { active: '0', on_sale_to_public: '1' } }

        flex_pass_offer.reload
        expect(flex_pass_offer).not_to be_active
        expect(flex_pass_offer).not_to be_on_sale_to_public
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

  describe 'DELETE #destroy' do
    let!(:flex_pass_offer) { FactoryBot.create(:flex_pass_offer, theater: theater) }

    it 'destroys the offer and returns to the admin listing' do
      expect do
        delete :destroy, params: { id: flex_pass_offer.id }
      end.to change(FlexPassOffer, :count).by(-1)

      expect(response).to redirect_to(admin_flex_pass_offers_url)
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
