class LinkToAddressOfRecordTask < OrderTask
  # Address consolidation must survive refunds and exchanges — the patron is
  # the same person regardless of the order's fate, so this task is excluded
  # from Order#cancel_pending_tasks.
  def cancel_with_order?
    false
  end

  protected

  def execute!
    # Created on transition to PROCESSED, so an unprocessed order here means
    # a rollback or in-flight transition; retry on a later poll.
    return false if order.unprocessed?

    order.link_to_address_of_record
  rescue ActiveRecord::RecordNotFound
    # The duplicate was consumed by a concurrent merge (hourly sweep or an
    # overlapping task run); the consolidation is already done.
    true
  rescue StandardError => e
    self.result = "#{e.message}\n#{e.backtrace.join("\n")}"
    false
  end
end
