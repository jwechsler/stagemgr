# The hard cap on ResourcedTicketClass device pools (assistive captioning
# tablets and the like) for a ticket order.
#
# Unlike TicketOrder#ticket_stock_available this is NOT scoped to one
# performance: the same physical devices are shared with every performance in
# the resource's venues whose occupancy window overlaps this one.
#
# It is a plain `validate`, so it runs on every save and therefore covers web
# checkout, the box office, the PROCESSED gate
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
    return if ticket_line_items.empty?
    return if performance.nil?

    requested_devices_by_resource.each do |resource, requested|
      # A refund-only net is giving devices back, not asking for them.
      next unless requested > 0

      remaining = resource.remaining_for(performance, exclude_order: self)
      next if requested <= remaining

      errors.add(:base, resourced_stock_message(resource, remaining))
    end
  end

  private

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
