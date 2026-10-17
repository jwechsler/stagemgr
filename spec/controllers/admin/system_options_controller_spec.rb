# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SystemOptionsController, type: :controller do
  render_views

  let!(:default_theater) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  before { allow(controller).to receive(:current_user).and_return(FactoryBot.create(:admin_user)) }

  it 'hides the Little Green Light sync links when LGL is disabled' do
    get :index

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Little Green Light sync', %(href="#{admin_lgl_sync_path}"))
  end

  it 'shows them when LGL is enabled' do
    allow(Lgl).to receive(:enabled?).and_return(true)

    get :index

    expect(response.body).to include('Little Green Light sync', '>LGL Sync<')
  end
end
