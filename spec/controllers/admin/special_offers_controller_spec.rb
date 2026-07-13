require 'rails_helper'

RSpec.describe Admin::SpecialOffersController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }

  before { allow(controller).to receive(:current_user).and_return(admin_user) }

  def datatable_params(status_scope: nil)
    columns = %w[code description number_of_uses status expires]
              .each_with_index.to_h do |col, i|
      [i.to_s, { data: col, searchable: 'true', orderable: 'true',
                 search: { value: '', regex: 'false' } }]
    end
    params = { draw: '1', start: '0', length: '25',
               search: { value: '', regex: 'false' }, columns: columns }
    params[:status_scope] = status_scope if status_scope
    params
  end

  describe 'GET #index' do
    it 'renders the deactivate-stale button with a not-undoable confirmation' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Deactivate Stale Offers')
      expect(response.body).to include('This cannot be undone')
    end

    it 'hides the deactivate-stale button outside development and test' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Deactivate Stale Offers')
    end

    it 'renders Active and Expired/Inactive tabs, each with its own scoped table' do
      get :index

      expect(response.body).to include('active_special_offer_listing')
      expect(response.body).to include('inactive_special_offer_listing')
      expect(response.body).to include('status_scope=active')
      expect(response.body).to include('status_scope=inactive')
    end

    context 'as JSON' do
      let!(:active_offer)   { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::ACTIVE) }
      let!(:inactive_offer) { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::INACTIVE) }
      let!(:expired_offer)  { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::EXPIRED) }
      let!(:system_offer) do
        FactoryBot.create(:percent_off_special_offer,
                          status: SpecialOffer::ACTIVE, system_generated: true)
      end

      def listed_codes
        response.parsed_body['data'].pluck('code').join
      end

      it 'returns only Active offers for status_scope=active' do
        get :index, params: datatable_params(status_scope: 'active'), format: :json

        expect(listed_codes).to include(active_offer.code)
        expect(listed_codes).not_to include(inactive_offer.code, expired_offer.code)
      end

      it 'returns Inactive and Expired offers for status_scope=inactive' do
        get :index, params: datatable_params(status_scope: 'inactive'), format: :json

        expect(listed_codes).to include(inactive_offer.code, expired_offer.code)
        expect(listed_codes).not_to include(active_offer.code)
      end

      it 'returns all statuses when status_scope is omitted' do
        get :index, params: datatable_params, format: :json

        expect(listed_codes).to include(active_offer.code, inactive_offer.code, expired_offer.code)
      end

      it 'never lists system-generated offers' do
        get :index, params: datatable_params(status_scope: 'active'), format: :json

        expect(listed_codes).not_to include(system_offer.code)
      end
    end
  end

  describe 'POST #deactivate_stale' do
    it 'enqueues the deactivation job and redirects with a notice' do
      expect(Resque).to receive(:enqueue).with(DeactivateStaleSpecialOffers)

      post :deactivate_stale

      expect(response).to redirect_to(admin_special_offers_path)
      expect(flash[:notice]).to match(/deactivation queued/i)
    end
  end
end
