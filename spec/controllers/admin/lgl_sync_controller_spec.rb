require 'rails_helper'

RSpec.describe Admin::LglSyncController, type: :controller do
  render_views

  let!(:default_theater) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(Resque).to receive(:enqueue)
  end

  describe 'GET #index when disabled' do
    it 'says why and shows no buttons, review list or menu link' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Little Green Light sync is disabled (littlegreenlight.sync).')
      expect(response.body).not_to include('Poll now', 'Sweep now', 'Backfill', 'LGL Review', 'Linked customers')
      expect(response.body).not_to include(%(href="#{admin_lgl_sync_path}"))
    end

    it 'names the missing key when sync is enabled without one' do
      allow(Lgl).to receive(:settings)
        .and_return(Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => 'enabled' } }, env: {}))

      get :index

      expect(response.body).to include('enabled (littlegreenlight.sync) but LGL_API_KEY is missing')
      expect(response.body).not_to include('Poll now')
    end

    it 'names readonly mode when the key is missing' do
      allow(Lgl).to receive(:settings)
        .and_return(Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => 'readonly' } }, env: {}))

      get :index

      expect(response.body).to include('sync is readonly (littlegreenlight.sync) but LGL_API_KEY is missing')
    end
  end

  describe 'GET #index' do
    before { allow(Lgl).to receive(:enabled?).and_return(true) }

    it 'shows the status and links each customer awaiting review to their page' do
      flagged = FactoryBot.create(:address, full_name: 'Pat Reviewme')
      flagged.lgl_review!('2 LGL constituents share this email')
      FactoryBot.create(:address).set_lgl_id!(4321)

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Little Green Light sync', 'LGL Review (1)', 'Linked customers')
      expect(response.body).to include(%(<a href="#{admin_address_path(flagged)}">Pat Reviewme</a>))
      expect(response.body).to include('2 LGL constituents share this email')
    end

    it 'says the poll has not started yet and the sweep never ran when neither has run' do
      get :index

      expect(response.body).to include('not yet (starts from the first scheduled poll)')
      expect(response.body).to match(%r{<th>Last sweep finished</th>\s*<td>never</td>})
    end

    it 'formats the recorded poll watermark' do
      JobMetadata.record_run_at(LglPollConstituents::WATERMARK, Time.zone.local(2026, 10, 1, 14, 30))

      get :index

      # Stored and read back in process-local time (default_timezone :local).
      recorded = JobMetadata.last_run(LglPollConstituents::WATERMARK)
      expect(response.body).to include(recorded.to_formatted_s(:short_date_and_time))
      expect(response.body).not_to include('not yet')
    end

    def lgl_settings(sync, env: {})
      Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => sync } }, env: env)
    end

    it 'lists the writable address ids and where they come from in readonly mode' do
      settings = lgl_settings('readonly', env: { 'LGL_WRITABLE_ADDRESS_IDS' => '42,7' })
      allow(Lgl).to receive_messages(read_only?: true, writable_address_ids: Set[42, 7], settings: settings)

      get :index

      expect(response.body).to include('Read-only (littlegreenlight.sync)', 'except address ids 7, 42')
      expect(response.body).to include('from ENV LGL_WRITABLE_ADDRESS_IDS')
      expect(response.body).to match(%r{<th>Sync</th>\s*<td>\s*Read-only\s*\(littlegreenlight.sync\)})
    end

    it 'says enabled was downgraded when read-only in development' do
      allow(Lgl).to receive_messages(read_only?: true, writable_address_ids: Set[], settings: lgl_settings('enabled'))

      get :index

      expect(response.body).to include('Read-only in development')
      expect(response.body).to match(%r{<th>Sync</th>\s*<td>\s*Enabled})
      expect(response.body).not_to include('except address ids')
    end

    it 'shows writes enabled and the allowlist as ignored in enabled mode' do
      settings = lgl_settings('enabled', env: { 'LGL_WRITABLE_ADDRESS_IDS' => '42' })
      allow(Lgl).to receive_messages(read_only?: false, settings: settings)

      get :index

      expect(response.body).to match(%r{<th>Writes to LGL</th>\s*<td>\s*Enabled})
      expect(response.body).to include('(ignored unless sync is readonly)')
      expect(response.body).not_to include('Read-only')
    end

    it 'shows the menu link and the run-now buttons' do
      get :index

      expect(response.body).to include('Poll now', 'Sweep now', %(href="#{admin_lgl_sync_path}"))
    end

    it 'turns away a box office user' do
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :index

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
    end
  end

  describe 'GET #index donor-tier report rows' do
    let(:supervisor_email) { Rails.configuration.x.email_address['supervisor_notifications'] }

    def report_settings(url: nil, env: {})
      Lgl::Settings.from({ 'littlegreenlight' => { 'donor_tier_report_url' => url } }, env: env)
    end

    it 'shows the report off and both times never, with no fetch button, when the link is blank' do
      get :index

      expect(response.body).to match(%r{<th>Donor-tier report</th>\s*<td>\s*Off})
      expect(response.body).to match(%r{<th>Last report download</th>\s*<td>never</td>})
      expect(response.body).to match(%r{<th>Last donor levels import</th>\s*<td>never</td>})
      expect(response.body).not_to include('Fetch donor levels now')
    end

    it 'shows the report on with its source and recipient and the fetch button while the API sync is disabled' do
      allow(Lgl).to receive(:settings).and_return(report_settings(url: 'https://lgl.example/r.csv'))

      get :index

      expect(response.body).to include("On (littlegreenlight.donor_tier_report_url), results to #{supervisor_email}")
      expect(response.body).to include('Fetch donor levels now', admin_lgl_sync_donor_levels_path)
      expect(response.body).not_to include('Poll now')
    end

    it 'names the ENV variable when the link comes from ENV, beside the sync buttons when sync is on' do
      allow(Lgl).to receive_messages(enabled?: true, read_only?: false,
                                     settings: report_settings(env: { 'LGL_DONOR_TIER_REPORT_URL' => 'https://lgl.example/r.csv' }))

      get :index

      expect(response.body).to include('On (LGL_DONOR_TIER_REPORT_URL)')
      expect(response.body).to include('Poll now', 'Fetch donor levels now')
    end

    it 'formats the last download and import times' do
      JobMetadata.record_run_at('LglDonorLevelsFetch', Time.zone.local(2026, 10, 1, 4, 30))
      JobMetadata.record_run_at('LglDonorImport', Time.zone.local(2026, 10, 1, 4, 35))

      get :index

      fetched = JobMetadata.last_run('LglDonorLevelsFetch').to_formatted_s(:short_date_and_time)
      imported = JobMetadata.last_run('LglDonorImport').to_formatted_s(:short_date_and_time)
      expect(response.body).to match(%r{<th>Last report download</th>\s*<td>#{Regexp.escape(fetched)}</td>})
      expect(response.body).to match(%r{<th>Last donor levels import</th>\s*<td>#{Regexp.escape(imported)}</td>})
    end
  end

  describe 'run-now buttons' do
    { poll: LglPollConstituents, sweep: LglSweepConstituents, backfill: LglBackfillLinks }.each do |action, job|
      it "#{action} queues #{job} when LGL is configured" do
        allow(Lgl).to receive(:enabled?).and_return(true)

        post action

        expect(Resque).to have_received(:enqueue).with(job)
        expect(response).to redirect_to(admin_lgl_sync_path)
        expect(flash[:notice]).to start_with('Queued')
      end

      it "#{action} queues nothing and alerts when LGL is not configured" do
        post action

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(admin_lgl_sync_path)
        expect(flash[:alert]).to eq('Little Green Light is not configured')
      end
    end

    it 'donor_levels queues LglDonorLevelsFetch when the report link is set, even with sync disabled' do
      allow(Lgl).to receive(:settings)
        .and_return(Lgl::Settings.from({ 'littlegreenlight' => { 'donor_tier_report_url' => 'https://lgl.example/r.csv' } },
                                       env: {}))

      post :donor_levels

      expect(Resque).to have_received(:enqueue).with(LglDonorLevelsFetch)
      expect(response).to redirect_to(admin_lgl_sync_path)
      expect(flash[:notice]).to eq('Queued a download of the LGL donor-tier report')
    end

    it 'donor_levels queues nothing and alerts when the report link is not set' do
      allow(Lgl).to receive(:enabled?).and_return(true)

      post :donor_levels

      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(admin_lgl_sync_path)
      expect(flash[:alert]).to eq('The LGL donor-tier report is not configured')
    end

    it 'refuses a box office user without queuing' do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      post :poll

      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(root_path)
    end
  end
end
