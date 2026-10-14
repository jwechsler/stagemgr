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

    it 'says never when the poll and sweep have not run' do
      get :index

      expect(response.body.scan('never').size).to eq(2)
    end

    it 'formats the recorded poll watermark' do
      JobMetadata.record_run_at(LglPollConstituents::WATERMARK, Time.zone.local(2026, 10, 1, 14, 30))

      get :index

      # Stored and read back in process-local time (default_timezone :local).
      recorded = JobMetadata.last_run(LglPollConstituents::WATERMARK)
      expect(response.body).to include(recorded.to_formatted_s(:short_date_and_time))
      expect(response.body.scan('never').size).to eq(1)
    end

    it 'lists the writable address ids and where they come from when LGL is read-only' do
      settings = Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => 'enabled' } },
                                    env: { 'LGL_WRITABLE_ADDRESS_IDS' => '42,7' })
      allow(Lgl).to receive_messages(read_only?: true, writable_address_ids: Set[42, 7], settings: settings)

      get :index

      expect(response.body).to include('Read-only in this environment', 'except address ids 7, 42')
      expect(response.body).to include('from ENV LGL_WRITABLE_ADDRESS_IDS', 'Enabled', '(littlegreenlight.sync)')
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

    it 'refuses a box office user without queuing' do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      post :poll

      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(root_path)
    end
  end
end
