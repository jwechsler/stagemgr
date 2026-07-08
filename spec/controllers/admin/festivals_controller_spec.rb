require 'rails_helper'

RSpec.describe Admin::FestivalsController, type: :controller do
  render_views

  let(:admin_user)      { FactoryBot.create(:admin_user) }
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:theater_user)    { FactoryBot.create(:user) }

  let!(:festival) { FactoryBot.create(:festival) }

  describe 'as an admin' do
    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    describe 'GET #index' do
      it 'lists festivals' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(festival.name)
      end
    end

    describe 'GET #show' do
      it 'renders the festival' do
        get :show, params: { id: festival.id }
        expect(response).to have_http_status(:ok)
      end

      it 'shows the full landing page URL when the landing page is enabled' do
        with_landing = FactoryBot.create(:festival, :with_landing_page, url_name: 'fringe-fest')

        get :show, params: { id: with_landing.id }

        expect(response.body).to include(festival_url('fringe-fest'))
      end

      it 'lists member productions with their dates, ordered by preview date' do
        second = FactoryBot.create(:production, name: 'Later Show', festival: festival,
                                                first_preview_at: Date.new(2026, 8, 1),
                                                closing_at: Date.new(2026, 8, 9))
        first = FactoryBot.create(:production, name: 'Earlier Show', festival: festival,
                                               first_preview_at: Date.new(2026, 7, 8),
                                               closing_at: Date.new(2026, 7, 15))

        get :show, params: { id: festival.id }

        expect(response.body).to include('July 8 – July 15, 2026')
        expect(response.body).to include(first.venue.name)
        expect(response.body.index(first.name)).to be < response.body.index(second.name)
      end
    end

    describe 'GET #new' do
      it 'renders the new form' do
        get :new
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET #edit' do
      it 'renders the edit form' do
        get :edit, params: { id: festival.id }
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST #create' do
      let(:valid_params) do
        { festival: { name: 'New Festival', status: Festival::ACTIVE } }
      end

      it 'creates a festival' do
        expect do
          post :create, params: valid_params
        end.to change(Festival, :count).by(1)
      end

      it 'redirects to the festivals index' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_festivals_path)
      end

      context 'with invalid params' do
        let(:invalid_params) { { festival: { name: '', status: Festival::ACTIVE } } }

        it 'does not create a festival' do
          expect do
            post :create, params: invalid_params
          end.not_to change(Festival, :count)
        end

        it 'renders the new template' do
          post :create, params: invalid_params
          expect(response).to render_template(:new)
        end
      end
    end

    describe 'PATCH #update' do
      it 'updates the festival' do
        patch :update, params: { id: festival.id, festival: { name: 'Renamed Festival' } }
        expect(festival.reload.name).to eq('Renamed Festival')
      end

      it 'redirects to the festival' do
        patch :update, params: { id: festival.id, festival: { name: 'Renamed Festival' } }
        expect(response).to redirect_to(admin_festival_path(festival))
      end
    end

    describe 'DELETE #destroy' do
      it 'destroys a festival with no productions' do
        expect do
          delete :destroy, params: { id: festival.id }
        end.to change(Festival, :count).by(-1)
      end

      it 'redirects to the festivals index' do
        delete :destroy, params: { id: festival.id }
        expect(response).to redirect_to(admin_festivals_path)
      end

      context 'when productions are still assigned' do
        let!(:production) { FactoryBot.create(:production, festival: festival) }

        it 'does not destroy the festival' do
          expect do
            delete :destroy, params: { id: festival.id }
          end.not_to change(Festival, :count)
        end

        it 'redirects back to the festival with an alert' do
          delete :destroy, params: { id: festival.id }
          expect(response).to redirect_to(admin_festival_path(festival))
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe 'as a box office user' do
    before { allow(controller).to receive(:current_user).and_return(box_office_user) }

    it 'allows reading festivals' do
      get :show, params: { id: festival.id }
      expect(response).to have_http_status(:ok)
    end

    it 'allows creating festivals' do
      expect do
        post :create, params: { festival: { name: 'Box Office Festival', status: Festival::ACTIVE } }
      end.to change(Festival, :count).by(1)
    end

    it 'denies destroying festivals' do
      delete :destroy, params: { id: festival.id }
      expect(response).to redirect_to(root_path)
      expect(Festival.exists?(festival.id)).to be true
    end
  end

  describe 'as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'allows reading festivals' do
      get :show, params: { id: festival.id }
      expect(response).to have_http_status(:ok)
    end

    it 'denies creating festivals' do
      post :create, params: { festival: { name: 'Theater Festival', status: Festival::ACTIVE } }
      expect(response).to redirect_to(root_path)
    end

    it 'denies destroying festivals' do
      delete :destroy, params: { id: festival.id }
      expect(response).to redirect_to(root_path)
      expect(Festival.exists?(festival.id)).to be true
    end
  end
end
