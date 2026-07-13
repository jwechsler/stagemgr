# Deletes addresses with no purchase history and no tags. An address with no
# orders cannot have production attendance (attendance derives from
# orders.address_id), so the orders anti-join subsumes the per-address
# productions_attended check the old implementation ran in Ruby.
#
# A JobMetadata watermark records the updated_at horizon already examined, so
# each run only scans addresses that became stale since the last run instead
# of re-walking the whole table. An address touched after being examined
# re-enters the window on a later run; a tag removed without saving the
# address does not (accepted trade-off — the address just survives).
class RemoveUnusedAddresses
  @queue = :maintenance

  WATERMARK = 'unused_addresses_examined_through'.freeze
  MINIMUM_AGE = 1.day

  def self.perform
    examined_through = JobMetadata.last_run(WATERMARK)
    upper = MINIMUM_AGE.ago
    return 0 if examined_through >= upper

    removed = 0
    candidates(examined_through, upper).find_each do |address|
      removed += 1 if address.destroy
    end

    JobMetadata.find_or_initialize_by(job_name: WATERMARK).update!(last_run_at: upper)
    removed
  end

  def self.candidates(lower, upper)
    Address.where.missing(:orders, :address_tags)
           .where(updated_at: lower...upper)
  end
end
