# The hard cap on ResourcedTicketClass device pools (assistive captioning
# tablets and the like) for a ticket order.
#
# Unlike TicketOrder#ticket_stock_available this is NOT scoped to one
# performance: the same physical devices are shared with every performance in
# the resource's venues whose occupancy window overlaps this one.
#
# It is a plain `validate`, so it runs on every save of an unsettled order and
# therefore covers web checkout, the box office, the PROCESSED gate
# (Order#transition_processing_to_processed! saves only `if valid?`, before the
# payment is taken), exchanges, holds, bulk imports and flex-pass autofulfill.
# There is deliberately no box_office_sale bypass -- the constraint is physical,
# not policy.
module ResourcedStockValidatable
  extend ActiveSupport::Concern

  included do
    validate :resourced_stock_available, unless: :allow_deletion?
  end

  def resourced_stock_available
    # CRITICAL: only orders that actually consume the pool are checked. An order
    # moving to Refunded / Exchanged / Released / Canceled / Unclaimed is GIVING
    # DEVICES BACK; blocking it would make refunds impossible the moment the pool
    # were shrunk below current usage.
    return unless Order::RESOURCE_OCCUPYING_STATUSES.include?(status)
    # A settled order (PROCESSED/FULFILLED) already has its devices; shrinking
    # the pool afterwards must not block it being saved again (e.g. marked
    # FULFILLED after printing). The PROCESSED gate is unaffected: that check
    # runs via valid? while the order is still PROCESSING.
    return if settled?
    return if ticket_line_items.empty?
    return if performance.nil?

    requested_devices_by_resource.each do |resource, requested|
      # A refund-only net is giving devices back, not asking for them.
      next unless requested > 0

      remaining = resource.remaining_for(performance, exclude_order: pool_exempt_orders)
      next if requested <= remaining

      errors.add(:base, resourced_stock_message(resource, remaining))
    end
  end

  private

  # Orders whose devices must not count against this order's pool check.
  #
  # Besides the order itself, that is the source order of an in-flight
  # exchange: TicketOrder#begin_exchange! sets the source to RELEASING in
  # memory only -- the row still says PROCESSED when this validation runs, and
  # an Order is never PERSISTED as RELEASING anywhere in the app -- so without
  # this exemption a same-pool exchange would be blocked at exactly-full
  # capacity by the very devices it is releasing. The exchange runs in a single
  # transaction (exchange_and_process_from!), so an aborted exchange rolls the
  # exemption's effects back with everything else.
  def pool_exempt_orders
    exempt = [self]
    if exchange_source && Order::RESOURCE_OCCUPYING_STATUSES.exclude?(exchange_source.status)
      exempt << exchange_source
    end
    exempt
  end

  def requested_devices_by_resource
    counts = Hash.new(0)
    ticket_line_items.each do |tli|
      tc = tli.ticket_class
      next if tc.nil? || !tc.resourced?

      counts[tc.resourced_ticket_class] += tli.ticket_count.to_i
    end
    counts
  end

  def resourced_stock_message(resource, remaining)
    if remaining > 0
      "There #{remaining == 1 ? 'is' : 'are'} only #{remaining} '#{resource.class_name}' " \
        'available for this date and time -- the shared equipment is in use at an ' \
        'overlapping performance.'
    else
      "Sorry, all '#{resource.class_name}' equipment is in use at performances " \
        'overlapping this one.'
    end
  end
end
