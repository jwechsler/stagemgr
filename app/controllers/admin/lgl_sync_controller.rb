# frozen_string_literal: true

# Little Green Light sync status for administrators: configuration, when the
# poll, sweep and gift history walk last finished, how many customers are
# linked and how many are lapsed donors, and the
# addresses waiting for a human to reconcile them in LGL, plus the nightly
# donor-tier report download (which needs only its link, not the API sync).
# The buttons only queue the jobs on the maintenance queue. The one call to LGL
# in a request is reading the campaign list, made only while no gift campaign
# is chosen or the administrator asks to change it (and when saving a choice).
class Admin::LglSyncController < Admin::ApplicationController
  # The review list is capped at this many conflicts (rows, not tagged
  # addresses); the page shows the full count beside it.
  REVIEW_LIMIT = 100
  JOBS = {
    poll: LglPollConstituents, sweep: LglSweepConstituents, backfill: LglBackfillLinks,
    donor_levels: LglDonorLevelsFetch, gift_history: LglGiftHistoryWalk
  }.freeze
  QUEUED = {
    poll: 'Queued a poll of recent LGL changes',
    sweep: 'Queued a sweep of every LGL ID',
    backfill: 'Queued the LGL backfill',
    donor_levels: 'Queued a download of the LGL donor-tier report',
    gift_history: "Queued a refresh of every linked customer's gift history"
  }.freeze
  NOT_CONFIGURED = 'Little Green Light is not configured'
  DONOR_LEVELS_NOT_CONFIGURED = 'The LGL donor-tier report is not configured'
  CAMPAIGN_INACTIVE = 'That LGL campaign is not active'
  CAMPAIGN_ERRORS = [Lgl::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED].freeze

  before_action :authorize_lgl_sync

  # Disabled (littlegreenlight.sync off, or no key), the page shows only why
  # and the donor-tier report rows, which do not depend on the API sync.
  def index
    @enabled = Lgl.enabled?
    @settings = Lgl.settings
    assign_donor_levels_status
    return unless @enabled

    @read_only = Lgl.read_only?
    @writable_address_ids = Lgl.writable_address_ids.to_a.sort
    @last_poll = recorded_time(LglPollConstituents::WATERMARK)
    @last_sweep = recorded_time(LglSweepConstituents::COMPLETED)
    @linked_count = AddressTag.lgl(AddressTag::LGL_ID).distinct.count(:address_id)
    @last_gift_history_walk = recorded_time(LglGiftHistoryWalk.name)
    @lapsed_counts = AddressTag.lgl(AddressTag::LGL_LAPSED).group(:tag_value).count
    review_list = Lgl::ReviewList.new(limit: REVIEW_LIMIT)
    @review_count = review_list.count
    @review_rows = review_list.rows
    assign_gift_status
  end

  def poll
    enqueue(:poll)
  end

  def sweep
    enqueue(:sweep)
  end

  def backfill
    enqueue(:backfill)
  end

  def gift_history
    enqueue(:gift_history)
  end

  def donor_levels
    enqueue(:donor_levels, allowed: Lgl.settings.donor_levels_enabled?, alert: DONOR_LEVELS_NOT_CONFIGURED)
  end

  # Re-reads the active campaigns so only one LGL still has open can be stored.
  def campaign
    return redirect_to(admin_lgl_sync_path, alert: NOT_CONFIGURED) unless Lgl.enabled?

    id = params.permit(:campaign_id)[:campaign_id].to_i
    @campaigns = active_campaigns
    return redirect_to(admin_lgl_sync_path, alert: @campaign_error) if @campaign_error

    chosen = @campaigns.find { |c| c['id'].to_i == id }
    return redirect_to(admin_lgl_sync_path, alert: CAMPAIGN_INACTIVE) if chosen.nil?

    LglSetting.store_campaign(chosen['id'], chosen['name'])
    redirect_to(admin_lgl_sync_path, notice: "LGL gift campaign set to #{chosen['name']}")
  end

  private

  def authorize_lgl_sync
    authorize! :manage, :lgl_sync
  end

  def enqueue(job, allowed: Lgl.enabled?, alert: NOT_CONFIGURED)
    return redirect_to(admin_lgl_sync_path, alert: alert) unless allowed

    Resque.enqueue(JOBS.fetch(job))
    redirect_to(admin_lgl_sync_path, notice: QUEUED.fetch(job))
  end

  # The campaign list comes from LGL, so it is read only when needed.
  def assign_gift_status
    @campaign = LglSetting.campaign
    @gift_count = DonationOrder.where.not(lgl_gift_id: nil).count
    @last_gift = recorded_time(Lgl::GiftReplicator::LAST_GIFT)
    @choosing_campaign = @campaign.nil? || params[:choose_campaign].present?
    @campaigns = active_campaigns if @choosing_campaign
  end

  def active_campaigns
    Lgl.client.campaigns.select { |c| c['is_active'] }.sort_by { |c| c['name'].to_s }
  rescue *CAMPAIGN_ERRORS => e
    @campaign_error = "Could not read campaigns from LGL: #{e.message}"
    []
  end

  # LglDonorImport also records manual uploads from the Imports page.
  def assign_donor_levels_status
    @donor_levels_enabled = @settings.donor_levels_enabled?
    @last_donor_levels_fetch = recorded_time(LglDonorLevelsFetch.name)
    @last_donor_levels_import = recorded_time(LglDonorImport.name)
    @donor_levels_recipient = Rails.configuration.x.email_address['supervisor_notifications']
  end

  # nil when the job has never recorded a run (JobMetadata answers the epoch).
  def recorded_time(job_name)
    time = JobMetadata.last_run(job_name)
    time.to_i.zero? ? nil : time
  end
end
