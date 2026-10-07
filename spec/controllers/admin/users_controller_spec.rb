require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }
  let!(:open_theater) { FactoryBot.create(:theater, name: 'Open House') }
  let!(:other_theater) { FactoryBot.create(:theater, name: 'Other House') }
  let!(:dark_theater) { FactoryBot.create(:theater, name: 'Dark House', status: Theater::INACTIVE) }
  let(:user) { FactoryBot.create(:user, theaters: [open_theater, dark_theater]) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  it 'lists only active theaters, even ones the user is linked to that are inactive' do
    get :edit, params: { id: user.id }

    options = Nokogiri::HTML(response.body).css('select[name="user[theater_ids][]"] option').map(&:text)
    expect(options).to include('Open House', 'Other House')
    expect(options).not_to include('Dark House')
  end

  it 'keeps links to inactive theaters when the form is saved' do
    patch :update, params: { id: user.id, user: { email: user.email, theater_ids: ['', other_theater.id.to_s] } }

    expect(user.reload.theaters).to contain_exactly(other_theater, dark_theater)
  end

  it 'leaves theater links alone when the form sends none' do
    patch :update, params: { id: user.id, user: { email: 'renamed@example.com' } }

    expect(user.reload.theaters).to contain_exactly(open_theater, dark_theater)
  end
end
