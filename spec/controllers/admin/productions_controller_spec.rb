require 'rails_helper'

RSpec.describe Admin::ProductionsController, type: :controller do
  render_views

  # Explicit names: the factory sequence ("Theater #n") can collide with the
  # production-name sequence ("Production #m") under datatable global search,
  # which tokenizes the term — searching "Theater #8" matches "Production #89".
  let(:theater)       { FactoryBot.create(:theater, name: 'Alpha Stage') }
  let(:other_theater) { FactoryBot.create(:theater, name: 'Zenith Playhouse') }
  let!(:production)       { FactoryBot.create(:production, theater: theater) }
  let!(:other_production) { FactoryBot.create(:production, theater: other_theater) }

  let(:admin_user)   { FactoryBot.create(:admin_user) }
  let(:theater_user) { FactoryBot.create(:user, theaters: [theater]) }

  def datatable_params(search: '')
    columns = %w[name theater season status actions].each_with_index.to_h do |col, i|
      [i.to_s, { data: col, searchable: 'true', orderable: 'false',
                 search: { value: '', regex: 'false' } }]
    end
    { draw: '1', start: '0', length: '25',
      search: { value: search, regex: 'false' }, columns: columns }
  end

  describe 'GET #index (global)' do
    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'renders the global index page' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('global-production-listing')
      end

      it 'returns productions across all theaters as JSON with a theater column' do
        get :index, params: datatable_params, format: :json
        payload = response.parsed_body
        names = payload['data'].pluck('name').join
        expect(names).to include(production.name)
        expect(names).to include(other_production.name)
        expect(payload['data'].first).to have_key('theater')
      end

      it 'filters by theater name through the global search' do
        get :index, params: datatable_params(search: other_theater.name), format: :json
        payload = response.parsed_body
        names = payload['data'].pluck('name').join
        expect(names).to include(other_production.name)
        expect(names).not_to include(production.name)
      end
    end

    context 'as a theater user' do
      before { allow(controller).to receive(:current_user).and_return(theater_user) }

      it 'only returns productions for granted theaters' do
        get :index, params: datatable_params, format: :json
        payload = response.parsed_body
        names = payload['data'].pluck('name').join
        expect(names).to include(production.name)
        expect(names).not_to include(other_production.name)
      end
    end
  end

  describe 'GET #search' do
    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    it 'returns matching productions for a whitelisted scope' do
      get :search, params: { q: production.name, scope: 'reports' }, format: :json
      labels = response.parsed_body.pluck('label').join
      expect(labels).to include(production.name)
    end

    it 'omits group entries when groups=0' do
      get :search, params: { q: theater.name, scope: 'reports', groups: '0' }, format: :json
      expect(response.parsed_body.none? { |r| r['group_key'] }).to be(true)
    end

    it 'rejects an unknown scope with 400' do
      get :search, params: { q: 'x', scope: 'evil' }, format: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET #resolve_group' do
    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    it 'expands a theater group into productions' do
      get :resolve_group, params: { group_key: "theater:#{theater.id}", scope: 'reports' },
                          format: :json
      names = response.parsed_body.pluck('name')
      expect(names).to include(production.name)
      expect(names).not_to include(other_production.name)
    end

    it 'rejects an unknown scope with 400' do
      get :resolve_group, params: { group_key: 'season:2025', scope: 'evil' }, format: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET #index (nested under theater)' do
    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    it 'still returns the per-theater datatable JSON' do
      params = datatable_params.merge(theater_id: theater.id)
      params[:columns] = params[:columns].reject { |_, c| c[:data] == 'theater' }
      get :index, params: params, format: :json
      payload = response.parsed_body
      names = payload['data'].pluck('name').join
      expect(names).to include(production.name)
      expect(names).not_to include(other_production.name)
    end

    it 'redirects HTML requests to the theater page' do
      get :index, params: { theater_id: theater.id }
      expect(response).to redirect_to(admin_theater_path(theater))
    end
  end
  # The box office verifies a production's follow-up copy with "Send sample
  # follow-up email". The preview builds a throwaway production, so anything it
  # fails to carry over is silently previewed at its house-wide default -- which
  # is how a working survey override looked broken.
  describe 'POST #send_sample_followup' do
    let!(:cash_payment_type) { FactoryBot.create(:cash_payment_type) }
    let(:production_with_links) do
      FactoryBot.create(:production, theater: theater,
                                     survey_link: 'https://survey.test/custom',
                                     mailing_list_link: 'https://mailing.test/custom')
    end

    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    def send_sample(params = {})
      post :send_sample_followup, params: {
        theater_id: theater.id, id: production_with_links.id
      }.merge(params)
    end

    it 'delivers a sample follow-up to the current user' do
      expect { send_sample }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be(true)
      expect(ActionMailer::Base.deliveries.last.to).to eq([admin_user.email])
    end

    it "uses the production's survey and mailing list overrides" do
      send_sample
      body = ActionMailer::Base.deliveries.last.body.decoded
      expect(body).to include('https://survey.test/custom')
      expect(body).to include('https://mailing.test/custom')
      expect(body).not_to include(Rails.configuration.x.server_config['survey_link'])
    end

    it 'previews unsaved survey and mailing list edits posted from the form' do
      send_sample(survey_link: 'https://survey.test/unsaved',
                  mailing_list_link: 'https://mailing.test/unsaved')
      body = ActionMailer::Base.deliveries.last.body.decoded
      expect(body).to include('https://survey.test/unsaved')
      expect(body).to include('https://mailing.test/unsaved')
    end

    it 'falls back to the house links when the production has no overrides' do
      bare = FactoryBot.create(:production, theater: theater, survey_link: nil, mailing_list_link: nil)
      post :send_sample_followup, params: { theater_id: theater.id, id: bare.id }
      body = ActionMailer::Base.deliveries.last.body.decoded
      expect(body).to include(Rails.configuration.x.server_config['survey_link'])
    end
  end
end
