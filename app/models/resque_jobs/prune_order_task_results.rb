# Clears the result column on old order tasks. OutreachTask and
# NotificationTask only ever store an exception message plus full backtrace
# there when a run fails (~8KB each); nothing reads the column back outside
# short-term debugging, and the accumulated blobs dominate the order_tasks
# tablespace. Runs weekly via schedule.yml. See docs/data-retention-strategy.md.
class PruneOrderTaskResults
  @queue = :maintenance

  RETENTION_MONTHS = 6
  BATCH_SIZE = 5_000
  BATCH_PAUSE_SECONDS = 1

  def self.perform
    cutoff = RETENTION_MONTHS.months.ago
    total = 0
    loop do
      cleared = OrderTask.where.not(result: nil)
                         .where(updated_at: ...cutoff)
                         .limit(BATCH_SIZE)
                         .update_all(result: nil)
      total += cleared
      break if cleared < BATCH_SIZE

      sleep BATCH_PAUSE_SECONDS
    end
    Rails.logger.info "PruneOrderTaskResults: cleared result on #{total} order tasks older than #{cutoff.to_date}"
    total
  end
end
