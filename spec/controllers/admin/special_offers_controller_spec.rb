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
  describe 'PATCH #update' do
    let(:address) { FactoryBot.create(:address) }
    let(:offer) { FactoryBot.create(:percent_off_special_offer, number_of_uses: 1) }

    def update_offer(return_to:)
      patch :update, params: { id: offer.id, return_to: return_to,
                               percent_off_special_offer: { code: offer.code, number_of_uses: '2' } }
    end

    it 'redirects to a local return_to path' do
      update_offer(return_to: admin_address_path(address))

      expect(response).to redirect_to(admin_address_path(address))
      expect(offer.reload.number_of_uses).to eq(2)
    end

    it 'falls back to the special offers list for an external return_to' do
      update_offer(return_to: 'https://evil.example.com/phish')

      expect(response).to redirect_to(admin_special_offers_path)
    end

    it 'falls back to the special offers list for a protocol-relative return_to' do
      update_offer(return_to: '//evil.example.com/phish')

      expect(response).to redirect_to(admin_special_offers_path)
    end
  end

  describe 'GET #edit' do
    it 'carries return_to through the form and points the breadcrumb at the member' do
      membership = FactoryBot.create(:membership)
      offer = TicketClassSpecialOffer.create!(code: 'MFTEST02', change_ticket_class_code: 'FRIEND',
                                              status: SpecialOffer::ACTIVE, system_generated: true,
                                              membership: membership)
      customer_path = admin_address_path(membership.address)

      get :edit, params: { id: offer.id, return_to: customer_path }

      expect(response.body).to match(/<input[^>]*name="return_to"[^>]*value="#{Regexp.escape(customer_path)}"/)
      expect(response.body).to include(membership.address.full_name)
    end
  end
end
