require 'rails_helper'

RSpec.describe Admin::LglSyncController, type: :controller do
  render_views

  let!(:default_theater) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:campaigns) do
    [{ 'id' => 1092, 'name' => 'Individual Giving', 'is_active' => true },
     { 'id' => 7, 'name' => 'Annual Fund 2019', 'is_active' => false },
     { 'id' => 1201, 'name' => 'Benefit', 'is_active' => true }]
  end
  let(:lgl_client) { instance_double(Lgl::Client, campaigns: campaigns) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(Resque).to receive(:enqueue)
    allow(Lgl).to receive(:client).and_return(lgl_client)
  end

  describe 'GET #index when disabled' do
    it 'says why and shows no buttons, review list or menu link' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Little Green Light sync is disabled (littlegreenlight.sync).')
      expect(response.body).not_to include('Poll for changes', 'Sweep all', 'Backfill', 'LGL Review', 'Linked customers')
      expect(response.body).not_to include('Refresh gift history', 'Lapsed donors', 'Last gift history walk')
      expect(response.body).not_to include(%(href="#{admin_lgl_sync_path}"))
    end

    it 'names the missing key when sync is enabled without one' do
      allow(Lgl).to receive(:settings)
        .and_return(Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => 'enabled' } }, env: {}))

      get :index

      expect(response.body).to include('enabled (littlegreenlight.sync) but LGL_API_KEY is missing')
      expect(response.body).not_to include('Poll for changes')
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
      flagged.lgl_review!('LGL constituents 11 and 12 share this email')
      FactoryBot.create(:address).set_lgl_id!(4321)

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Little Green Light sync', 'LGL Review (1)', 'Linked customers')
      expect(response.body).to include(%(<a href="#{admin_address_path(flagged)}">Pat Reviewme (##{flagged.id})</a>))
      expect(response.body).to include('LGL constituents 11 and 12 share this email', 'Customers (matched on email)', 'Actions')
      expect(response.body).not_to include(new_admin_address_merge_path)
    end

    it 'links each constituent a share-this-email reason names, in the Constituent and Reason columns' do
      allow(Lgl).to receive(:constituent_url) { |id| "https://example.littlegreenlight.com/constituents/#{id}" }
      FactoryBot.create(:address).lgl_review!('LGL constituents 11 and 12 share this email')

      get :index

      link = ->(id) { %(<a target="_blank" rel="noopener" href="https://example.littlegreenlight.com/constituents/#{id}">#{id}</a>) }
      expect(response.body).to include("LGL constituent #{link[11]}, LGL constituent #{link[12]}",
                                       "LGL constituents #{link[11]} and #{link[12]} share this email")
    end

    it 'shows customers matching one constituent as one row linking each customer, with a Merge button' do
      reason = "#{Lgl::ConstituentReplicator.several_matches_prefix(971_217)} named Derek Phillips by email"
      first = FactoryBot.create(:address, full_name: 'Derek Phillips', email: 'derek@example.com')
      second = FactoryBot.create(:address, full_name: 'Derek Phillip', email: 'derek@example.com')
      [first, second].each { |address| address.lgl_review!(reason) }

      get :index

      expect(response.body).to include('LGL Review (1)', 'Same first name, 1 email', 'LGL constituent 971217')
      expect(response.body).to match(/title=["']#{Regexp.escape(reason)}["']/)
      expect(response.body.scan(reason).size).to eq(1)
      expect(response.body).to include(%(href="#{admin_address_path(first)}"), %(href="#{admin_address_path(second)}"))
      merge_path = new_admin_address_merge_path(ids: [first.id, second.id], constituent_id: 971_217)
      expect(response.body).to include(%(<a class="button tiny" href="#{ERB::Util.html_escape(merge_path)}">Merge</a>))
      expect(response.body).not_to match(/data-confirm="Merge /)
    end

    it 'offers Merge when the matched customers have different first names' do
      reason = "#{Lgl::ConstituentReplicator.several_matches_prefix(920_008)} by email and last name"
      charles = FactoryBot.create(:address, full_name: 'Charles Kosalko', email: 'kosalko@example.com')
      gayle = FactoryBot.create(:address, full_name: 'Gayle Kosalko', email: 'kosalko@example.com')
      [charles, gayle].each { |address| address.lgl_review!(reason) }

      get :index

      merge_path = new_admin_address_merge_path(ids: [charles.id, gayle.id], constituent_id: 920_008)
      expect(response.body).to include('Different first names (Charles, Gayle), 1 email',
                                       ERB::Util.html_escape(merge_path))
    end

    it 'shows a pair linked to one constituent as one row linking both customers, without a Merge button' do
      jane = FactoryBot.create(:address, full_name: 'Jane Doe')
      other = FactoryBot.create(:address, full_name: 'Jane D')
      jane.lgl_review!("LGL constituent 5512 is also linked to ##{other.id}")
      other.lgl_review!("LGL constituent 5512 is also linked to ##{jane.id}")

      get :index

      expect(response.body).to include('LGL Review (1)', "LGL constituent 5512 is also linked to ##{other.id}")
      expect(response.body).not_to include("LGL constituent 5512 is also linked to ##{jane.id}")
      expect(response.body).to include(%(href="#{admin_address_path(jane)}"), %(href="#{admin_address_path(other)}"))
      expect(response.body).not_to include(new_admin_address_merge_path)
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

      expect(response.body).to include('Poll for changes', 'Sweep all', %(href="#{admin_lgl_sync_path}"))
      expect(response.body).to include('Refresh gift history', admin_lgl_sync_gift_history_path,
                                       'This takes about an hour.')
    end

    it 'counts default-theater lapsed donors by kind, and shows the gift history walk as never run' do
      2.times { FactoryBot.create(:address).set_lgl_lapsed!('LYBUNT') }
      FactoryBot.create(:address).set_lgl_lapsed!('SYBUNT')
      FactoryBot.create(:address).address_tags.create!(tag_label: AddressTag::LGL_LAPSED, tag_value: 'SYBUNT',
                                                       theater: FactoryBot.create(:theater))

      get :index

      expect(response.body).to match(%r{<th>Lapsed donors</th>\s*<td>\s*LYBUNT 2,\s*SYBUNT 1\s*</td>})
      expect(response.body).to match(%r{<th>Last gift history walk</th>\s*<td>never</td>})
    end

    it 'shows zero lapsed donors and the last gift history walk time' do
      JobMetadata.record_run_at('LglGiftHistoryWalk', Time.zone.local(2026, 10, 11, 2, 40))

      get :index

      walked = JobMetadata.last_run('LglGiftHistoryWalk').to_formatted_s(:short_date_and_time)
      expect(response.body).to match(%r{<th>Lapsed donors</th>\s*<td>\s*LYBUNT 0,\s*SYBUNT 0\s*</td>})
      expect(response.body).to match(%r{<th>Last gift history walk</th>\s*<td>#{Regexp.escape(walked)}</td>})
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
      expect(response.body).not_to include('Poll for changes')
    end

    it 'names the ENV variable when the link comes from ENV, beside the sync buttons when sync is on' do
      allow(Lgl).to receive_messages(enabled?: true, read_only?: false,
                                     settings: report_settings(env: { 'LGL_DONOR_TIER_REPORT_URL' => 'https://lgl.example/r.csv' }))

      get :index

      expect(response.body).to include('On (LGL_DONOR_TIER_REPORT_URL)')
      expect(response.body).to include('Poll for changes', 'Fetch donor levels now')
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

  describe 'GET #index gift campaign rows' do
    before { allow(Lgl).to receive(:enabled?).and_return(true) }

    it 'shows the chosen campaign and the donation count without calling LGL' do
      LglSetting.store_campaign(1092, 'Individual Giving')
      order = FactoryBot.create(:donation_order)
      order.update_column(:lgl_gift_id, 555)

      get :index

      expect(Lgl).not_to have_received(:client)
      expect(response.body).to include('Individual Giving (#1092)', %(href="#{admin_lgl_sync_path(choose_campaign: 1)}"))
      expect(response.body).to match(%r{<th>Donations in LGL</th>\s*<td>1</td>})
      expect(response.body).not_to include('Choose a campaign')
    end

    it 'offers the active campaigns sorted by name when none is chosen' do
      get :index

      expect(lgl_client).to have_received(:campaigns)
      expect(response.body).to include(admin_lgl_sync_campaign_path, 'Choose a campaign',
                                       'Donations are not sent to LGL until a campaign is chosen.')
      expect(response.body).to match(/<option value="1201">Benefit<.*<option value="1092">Individual Giving</m)
      expect(response.body).not_to include('Annual Fund 2019')
      expect(response.body).to match(%r{<th>Donations in LGL</th>\s*<td>0</td>})
    end

    it 'shows when a gift was last replicated' do
      LglSetting.store_campaign(1092, 'Individual Giving')
      JobMetadata.record_run_at(Lgl::GiftReplicator::LAST_GIFT, Time.zone.local(2026, 10, 14, 9, 15))

      get :index

      written = JobMetadata.last_run(Lgl::GiftReplicator::LAST_GIFT).to_formatted_s(:short_date_and_time)
      expect(response.body).to match(%r{<th>Last gift replicated</th>\s*<td>#{Regexp.escape(written)}</td>})
    end

    it 'says never when no gift has been replicated' do
      LglSetting.store_campaign(1092, 'Individual Giving')

      get :index

      expect(response.body).to match(%r{<th>Last gift replicated</th>\s*<td>never</td>})
    end

    it 'offers the campaigns with the current one selected when asked to change it' do
      LglSetting.store_campaign(1092, 'Individual Giving')

      get :index, params: { choose_campaign: 1 }

      expect(response.body).to include('Choose a campaign', '<option selected="selected" value="1092">')
      expect(response.body).not_to include('Donations are not sent to LGL')
    end

    it 'shows why the campaigns could not be read' do
      allow(lgl_client).to receive(:campaigns).and_raise(Lgl::Error.new('LGL is down'))

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('callout alert', 'Could not read campaigns from LGL: LGL is down')
    end
  end

  describe 'POST #campaign' do
    before { allow(Lgl).to receive(:enabled?).and_return(true) }

    it 'stores an active campaign and says so' do
      post :campaign, params: { campaign_id: '1092' }

      expect(LglSetting.campaign).to eq(LglSetting::Campaign.new(1092, 'Individual Giving'))
      expect(response).to redirect_to(admin_lgl_sync_path)
      expect(flash[:notice]).to eq('LGL gift campaign set to Individual Giving')
    end

    %w[7 999].each do |id|
      it "stores nothing and alerts for campaign #{id}, which is not active" do
        post :campaign, params: { campaign_id: id }

        expect(LglSetting.campaign).to be_nil
        expect(response).to redirect_to(admin_lgl_sync_path)
        expect(flash[:alert]).to eq('That LGL campaign is not active')
      end
    end

    it 'stores nothing and alerts when the campaigns cannot be read' do
      allow(lgl_client).to receive(:campaigns).and_raise(SocketError, 'getaddrinfo failed')

      post :campaign, params: { campaign_id: '1092' }

      expect(LglSetting.campaign).to be_nil
      expect(flash[:alert]).to eq('Could not read campaigns from LGL: getaddrinfo failed')
    end

    it 'stores nothing and alerts when LGL is not configured' do
      allow(Lgl).to receive(:enabled?).and_return(false)

      post :campaign, params: { campaign_id: '1092' }

      expect(Lgl).not_to have_received(:client)
      expect(LglSetting.campaign).to be_nil
      expect(flash[:alert]).to eq('Little Green Light is not configured')
    end
  end

  describe 'run-now buttons' do
    { poll: LglPollConstituents, sweep: LglSweepConstituents, backfill: LglBackfillLinks,
      gift_history: LglGiftHistoryWalk }.each do |action, job|
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

  describe 'a theater user' do
    before do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, theaters: [default_theater]))
    end

    it 'is turned away from the status page' do
      get :index

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
    end

    %i[poll sweep backfill donor_levels gift_history].each do |action|
      it "is refused #{action} without queuing" do
        post action

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not authorized to access this page.')
      end
    end

    it 'is refused a campaign change without reading LGL or storing one' do
      allow(LglSetting).to receive(:store_campaign)

      post :campaign, params: { campaign_id: 1092 }

      expect(lgl_client).not_to have_received(:campaigns)
      expect(LglSetting).not_to have_received(:store_campaign)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
    end
  end
end
