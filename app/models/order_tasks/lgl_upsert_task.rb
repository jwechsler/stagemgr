# frozen_string_literal: true

# Queues a Little Green Light sync for a processed donation's patron, then the
# donation's gift replication. Runs after LinkToAddressOfRecordTask has folded
# the checkout address into the address of record, and resolves the address at
# run time so the sync targets the surviving record.
class LglUpsertTask < OrderTask
  # Later than LinkToAddressOfRecordTask's 5 minutes.
  LGL_DELAY = 10.minutes
  DONATION_TRIGGER = 'donation'
  # The address sync normally links the constituent within seconds; the
  # replicate job then finds the LGL id, and backs off on NotLinked if it does
  # not.
  REPLICATE_DELAY = 3.minutes

  protected

  def execute! # rubocop:disable Naming/PredicateMethod -- OrderTask contract
    # Checked first: a task created before sync was turned off completes
    # rather than waiting on the address link and retrying forever.
    return true unless Lgl.enabled?

    order.reload # the merge task may have re-pointed address_id
    # False retries on a later poll.
    return false if order.unprocessed? || address_link_pending?

    address = order.address
    return true if address.nil? || address.placeholder?

    Resque.enqueue(LglSyncAddressJob, address.id, DONATION_TRIGGER)
    Resque.enqueue_in(REPLICATE_DELAY, LglReplicateDonationJob, order.id)
    true
  end

  private

  def address_link_pending?
    order.tasks.where(type: 'LinkToAddressOfRecordTask').any?(&:uncompleted?)
  end
end
