require 'rails_helper'

RSpec.describe FestivalsController, type: :controller do
  render_views

  describe 'GET #show' do
    it 'renders the festival and its member show cards when active with the landing page enabled' do
      festival = FactoryBot.create(:festival, :with_landing_page, status: Festival::ACTIVE, url_name: 'fringe-fest')
      member = FactoryBot.create(:production, festival: festival)

      get :show, params: { url_name: festival.url_name }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(festival.name)
      expect(response.body).to include(member.name)
    end

    it 'returns 404 when the landing page is disabled' do
      festival = FactoryBot.create(:festival, status: Festival::ACTIVE, landing_page_enabled: false, url_name: 'fringe-fest-2')

      get :show, params: { url_name: festival.url_name }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when the festival is inactive' do
      festival = FactoryBot.create(:festival, :with_landing_page, status: Festival::INACTIVE)

      get :show, params: { url_name: festival.url_name }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for an unknown URL name' do
      get :show, params: { url_name: 'no-such-festival' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
