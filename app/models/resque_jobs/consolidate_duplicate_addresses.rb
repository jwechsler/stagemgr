# Merges strict duplicate patron records — same search_name AND same email,
# both present, non-placeholder — into the oldest record via
# Address#merge_and_purge. This is the consistency backstop behind the
# per-order LinkToAddressOfRecordTask: it retroactively consolidates
# duplicates from any source the per-order path misses (task failures,
# order-less addresses, imports) and drains the historical backlog in
# bounded hourly batches. The keeper is the lowest id, matching
# Address#find_original's tie-break, so both mechanisms converge on the
# same record. Intentionally conservative: records with a blank email or a
# different email never auto-merge here (two different patrons can share a
# name).
class ConsolidateDuplicateAddresses
  @queue = :maintenance

  GROUP_LIMIT = 150

  # Statuses indicating an order mid-checkout or mid-exchange; groups
  # referenced by one are skipped this run rather than raced. HOLD is
  # deliberately merged — holds sit for weeks and update_all moves them
  # safely.
  IN_FLIGHT_STATUSES = (Order::TRANSITORY_STATUSES + [Order::EXCHANGING, Order::RELEASING]).freeze

  def self.perform(group_limit = GROUP_LIMIT)
    merged = 0
    groups = duplicate_groups(group_limit)
    groups.each { |search_name, email| merged += consolidate_group(search_name, email) }
    Rails.logger.info("ConsolidateDuplicateAddresses: merged #{merged} duplicates across #{groups.size} groups")
    merged
  end

  def self.duplicate_groups(limit)
    Address.where(placeholder: false)
           .where.not(search_name: [nil, ''])
           .where.not(email: [nil, ''])
           .group(:search_name, :email)
           .having('COUNT(*) > 1')
           .limit(limit)
           .pluck(:search_name, :email)
  end

  def self.consolidate_group(search_name, email)
    records = Address.where(placeholder: false, search_name: search_name, email: email)
                     .order(:id).to_a
    return 0 if records.size < 2
    return 0 if in_flight?(records)

    keeper = records.shift
    records.sum do |duplicate|
      keeper.merge_and_purge(duplicate)
      1
    rescue StandardError => e
      Rails.logger.warn(
        "ConsolidateDuplicateAddresses: skipped ##{duplicate.id} -> ##{keeper.id}: #{e.message}"
      )
      0
    end
  end

  def self.in_flight?(records)
    Order.exists?(address_id: records.map(&:id), status: IN_FLIGHT_STATUSES)
  end
end
