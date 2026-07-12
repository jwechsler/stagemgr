require 'rails_helper'

RSpec.describe Admin::SpecialOffersController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }

  before { allow(controller).to receive(:current_user).and_return(admin_user) }

  describe 'GET #index' do
    it 'renders the deactivate-stale button with a not-undoable confirmation' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Deactivate Stale Offers')
      expect(response.body).to include('This cannot be undone')
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
