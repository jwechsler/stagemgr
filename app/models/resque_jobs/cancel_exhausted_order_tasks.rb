# OrderTask.run_pending polls status IN ('Untried','Failed') with
# attempts < MAX_ATTEMPTS every 5 minutes. Failed tasks that have exhausted
# their attempts are terminal (OrderTask#uncompleted? never lets them run
# again) but they accumulate under status = 'Failed' and destroy the
# selectivity of the (status, execute_at) index, pushing the poll back to a
# full table scan. Marking them Cancelled is behaviorally neutral and keeps
# the poll on the index. The failure text in `result` is untouched
# (PruneOrderTaskResults clears it on its own schedule), and an admin retry
# still works — OrderTask#retry resets status and attempts regardless.
class CancelExhaustedOrderTasks
  @queue = :maintenance

  BATCH_SIZE = 5_000

  def self.perform
    cancelled = 0
    loop do
      batch = OrderTask.where(status: OrderTask::FAILED)
                       .where(attempts: OrderTask::MAX_ATTEMPTS..)
                       .limit(BATCH_SIZE)
                       .update_all(status: OrderTask::CANCELLED)
      cancelled += batch
      break if batch < BATCH_SIZE

      sleep 1
    end
    Rails.logger.info("CancelExhaustedOrderTasks: cancelled #{cancelled} exhausted Failed tasks")
    cancelled
  end
end
