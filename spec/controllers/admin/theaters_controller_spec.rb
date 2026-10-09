require 'rails_helper'

RSpec.describe Admin::TheatersController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  def selected_status
    Nokogiri::HTML(response.body).at_css('select[name="theater[status]"] option[selected]')&.text
  end

  it 'shows an inactive theater as Inactive on its edit page' do
    theater = FactoryBot.create(:theater, name: 'Dark House', status: Theater::INACTIVE)

    get :edit, params: { id: theater.id }

    expect(selected_status).to eq(Theater::INACTIVE)
  end

  it 'carries return_to into the edit form when the edit came from the index' do
    theater = FactoryBot.create(:theater, name: 'Linked House')

    get :edit, params: { id: theater.id, return_to: 'index' }

    expect(response.body).to include('name="return_to"').and include('value="index"')
  end

  it 'defaults a new theater to Active' do
    get :new

    expect(selected_status).to eq(Theater::ACTIVE)
  end

  describe 'DELETE #destroy' do
    it 'redirects back with the errors when a theater with productions cannot be destroyed' do
      theater = FactoryBot.create(:theater, name: 'Busy House')
      FactoryBot.create(:production, theater: theater)

      delete :destroy, params: { id: theater.id }

      expect(response).to redirect_to(admin_theater_path(theater))
      expect(flash[:error]).to be_present
      expect(Theater.exists?(theater.id)).to be true
    end
  end

  describe 'PATCH #update' do
    context 'when returning to the screen the edit came from' do
      let(:theater) { FactoryBot.create(:theater, name: 'Returning House') }
      let(:params)  { { id: theater.id, theater: { name: 'Renamed House' } } }

      it 'returns to the index when the edit came from the index' do
        patch :update, params: params.merge(return_to: 'index')
        expect(response).to redirect_to(admin_theaters_path)
      end

      it 'returns to the show page when no return_to is given' do
        patch :update, params: params
        expect(response).to redirect_to(admin_theater_path(theater))
      end

      it 'ignores an unrecognised return_to rather than redirecting to it' do
        patch :update, params: params.merge(return_to: 'https://evil.example.com')
        expect(response).to redirect_to(admin_theater_path(theater))
      end
    end

    it 'saves both donation appeals' do
      theater = FactoryBot.create(:theater, name: 'Appealing House')

      patch :update, params: { id: theater.id, theater: { donation_appeal: 'Love **{{theater}}**',
                                                          secondary_donation_appeal: 'We host {{company}}' } }

      expect(theater.reload).to have_attributes(donation_appeal: 'Love **{{theater}}**',
                                                secondary_donation_appeal: 'We host {{company}}')
    end
  end

  describe 'GET #show appeals tab' do
    it 'shows the stored default appeal as markdown' do
      theater = FactoryBot.create(:theater, name: 'Shown House', donation_appeal: 'Love **us**')

      get :show, params: { id: theater.id }

      expect(response.body).to include('Default appeal').and include('<strong>us</strong>')
    end

    it 'shows the secondary appeal for the default theater' do
      default_theater = FactoryBot.create(:theater, name: 'Default House', theater_class: Theater::DEFAULT)

      get :show, params: { id: default_theater.id }

      expect(response.body).to include('Secondary appeal')
    end

    it 'omits the secondary appeal for any other theater' do
      visiting = FactoryBot.create(:theater, name: 'Visiting House', theater_class: Theater::VISITING)

      get :show, params: { id: visiting.id }

      expect(response.body).not_to include('Secondary appeal')
    end
  end
end
