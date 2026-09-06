require 'rails_helper'

# The public membership list. What matters here is that every offer on the page
# can actually be bought: MembershipOfferOrdersController#new renders
# general/unavailable for anything off sale or timed, so a listed offer that
# does not pass MembershipOffer.on_sale_to_public is a dead buy button.
RSpec.describe MembershipOffersController, type: :controller do
  render_views

  describe 'GET #index' do
    it 'lists an on-sale production membership with its description and a buy link' do
      offer = FactoryBot.create(:membership_offer, name: 'Season Member',
                                                   html_description: 'Two seats to every show.')

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Season Member')
      expect(response.body).to include('Two seats to every show.')
      expect(response.body).to include(new_membership_offer_order_path(offer))
    end

    it 'excludes an inactive offer' do
      FactoryBot.create(:membership_offer, name: 'Retired Member', status: MembershipOffer::INACTIVE)

      get :index

      expect(response.body).not_to include('Retired Member')
    end

    it 'excludes an offer that is off sale' do
      FactoryBot.create(:membership_offer, name: 'Paused Member', on_sale: false)

      get :index

      expect(response.body).not_to include('Paused Member')
    end

    it 'excludes a timed library pass, which is never sold to the public' do
      FactoryBot.create(:membership_offer, :timed, name: 'Library Pass')

      get :index

      expect(response.body).not_to include('Library Pass')
    end

    it 'says so when nothing is on sale' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('no memberships on sale')
    end
  end
end
