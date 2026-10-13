# frozen_string_literal: true

# Little Green Light sync status for administrators: configuration, when the
# poll and sweep last finished, how many customers are linked, and the
# addresses waiting for a human to reconcile them in LGL. The buttons only
# queue the jobs on the lgl queue; nothing here calls LGL in the request.
class Admin::LglSyncController < Admin::ApplicationController
  # The review list is capped; the page shows the full count beside it.
  REVIEW_LIMIT = 100
  JOBS = { poll: LglPollConstituents, sweep: LglSweepConstituents, backfill: LglBackfillLinks }.freeze
  QUEUED = {
    poll: 'Queued a poll of recent LGL changes',
    sweep: 'Queued a sweep of every LGL ID',
    backfill: 'Queued the LGL backfill'
  }.freeze

  before_action :authorize_lgl_sync

  def index
    @enabled = Lgl.enabled?
    @read_only = Lgl.read_only?
    @writable_address_ids = Lgl.writable_address_ids.to_a.sort
    @last_poll = recorded_time(LglPollConstituents::WATERMARK)
    @last_sweep = recorded_time(LglSweepConstituents::COMPLETED)
    @linked_count = lgl_tags(AddressTag::LGL_ID).distinct.count(:address_id)
    review_tags = lgl_tags(AddressTag::LGL_REVIEW)
    @review_count = review_tags.count
    @review_tags = review_tags.includes(:address).order(:created_at, :id).limit(REVIEW_LIMIT)
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

  private

  def authorize_lgl_sync
    authorize! :manage, :lgl_sync
  end

  def enqueue(job)
    return redirect_to(admin_lgl_sync_path, alert: 'Little Green Light is not configured') unless Lgl.enabled?

    Resque.enqueue(JOBS.fetch(job))
    redirect_to(admin_lgl_sync_path, notice: QUEUED.fetch(job))
  end

  # nil when the job has never recorded a run (JobMetadata answers the epoch).
  def recorded_time(job_name)
    time = JobMetadata.last_run(job_name)
    time.to_i.zero? ? nil : time
  end

  def lgl_tags(label)
    theater_id = Theater.default_theater&.id
    return AddressTag.none if theater_id.nil?

    AddressTag.where(tag_label: label, theater_id: theater_id)
  end
end
