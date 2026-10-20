# frozen_string_literal: true

# Admin > Merge customers: 2 to Address::ManualMerge::MAX_RECORDS customers
# side by side, staff choosing whose name, address, email, phone and LGL ID the
# kept record (the lowest id) ends up with. Reached from Merge Selected on the
# Customers page and from Merge on an LGL Review row, which also passes the
# row's constituent_id so the kept customer is re-linked to it afterwards.
class Admin::AddressMergesController < Admin::ApplicationController
  MERGE_FAILED = 'Merge failed. See server log.'

  before_action :authorize_merge
  before_action :assign_constituent_id

  def new
    @merge = Address::ManualMerge.new(ids: merge_ids)
    @cancel_path = default_back_path
  rescue Address::ManualMerge::Error => e
    redirect_to(back_path, alert: e.message)
  end

  # perform! is one transaction, so after any failure every customer is as it
  # was and the page can be shown again.
  def create
    merge = Address::ManualMerge.new(ids: merge_ids, choices: merge_choices)
    master = merge.perform!
    redirect_after_merge(master, merge.ids.size)
  rescue Address::ManualMerge::Error => e
    redirect_to(retry_path, alert: e.message)
  rescue StandardError => e
    Rails.logger.error("Merge of customers #{merge_ids.inspect} failed: #{e.class}: #{e.message}\n" \
                       "#{Array(e.backtrace).join("\n")}")
    redirect_to(retry_path, alert: MERGE_FAILED)
  end

  private

  def authorize_merge
    authorize! :merge, Address
  end

  # The LGL constituent an LGL Review row's Merge was for; nil when absent or
  # not a number.
  def assign_constituent_id
    @constituent_id = Integer(params[:constituent_id].to_s, exception: false)
  end

  def merge_ids
    params.permit(ids: [])[:ids]
  end

  def merge_choices
    params.permit(choices: Address::ManualMerge::FIELDS)[:choices].to_h
  end

  def redirect_after_merge(master, count)
    if @constituent_id && Lgl.enabled?
      notice = merged_notice(count, master, @constituent_id, queue_relink(master))
      redirect_to(admin_lgl_sync_path, notice: notice)
    else
      redirect_to(admin_address_path(master), notice: "Merged #{count} customers into ##{master.id}")
    end
  end

  # Queues the kept customer to adopt the constituent by email; false (logged)
  # when the job could not be queued.
  def queue_relink(master)
    Resque.enqueue(LglSyncAddressJob, master.id, LglSyncAddressJob::LINK_TRIGGER)
    true
  rescue StandardError => e
    Rails.logger.error("[LGL] could not queue the re-link of ##{master.id}: #{e.class}: #{e.message}")
    false
  end

  def merged_notice(count, master, lgl_id, relinked)
    notice = "Merged #{count} customers into ##{master.id}"
    return "#{notice}; re-linking to LGL constituent #{lgl_id}" if relinked

    "#{notice}, but re-linking to LGL constituent #{lgl_id} could not be queued: " \
      "use Re-sync on the customer's page"
  end

  def retry_path
    new_admin_address_merge_path(ids: merge_ids, constituent_id: @constituent_id)
  end

  # The page that linked here, unless it is on another host or is this page
  # (a create error bounced back to a set that can no longer be merged).
  def back_path
    uri = URI.parse(request.referer.to_s)
    return default_back_path if uri.path.to_s.empty? || uri.path.include?(admin_address_merge_path)
    return default_back_path if uri.host && uri.host != request.host

    request.referer
  rescue URI::InvalidURIError
    default_back_path
  end

  def default_back_path
    @constituent_id ? admin_lgl_sync_path : admin_addresses_path
  end
end
