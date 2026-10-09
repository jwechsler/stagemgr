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
    it 'saves both donation appeals' do
      theater = FactoryBot.create(:theater, name: 'Appealing House')

      patch :update, params: { id: theater.id, theater: { donation_appeal: 'Love **{{theater}}**',
                                                          secondary_donation_appeal: 'We host {{company}}' } }

      expect(theater.reload).to have_attributes(donation_appeal: 'Love **{{theater}}**',
                                                secondary_donation_appeal: 'We host {{company}}')
    end
  end

  it 'shows the stored donation appeals as markdown on the theater page' do
    theater = FactoryBot.create(:theater, name: 'Shown House', donation_appeal: 'Love **us**')

    get :show, params: { id: theater.id }

    expect(response.body).to include('Default appeal').and include('<strong>us</strong>')
  end
end
