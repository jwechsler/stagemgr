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
end
