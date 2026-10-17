# LEGACY backfill (rake legacy_line_items:split_aggregates). Converts each
# aggregated seat-holding TicketLineItem on an upcoming reserved-seating order
# into one per-seat line item per SeatAssignment of that ticket class, using
# the same split as TicketOrder#sync_reserved_seat_price_overrides
# (LegacyAggregateLineItems#split_seat_from_aggregate!). The aggregates come
# only from CSV bulk order imports made before 2026-10-01; see that concern.
#
# An order whose unlinked seats of a class do not number exactly the
# aggregate's ticket_count is skipped and reported, never guessed at.
class LegacyAggregateSplitter
  Result = Struct.new(:order_id, :status, :seats_split, :message, keyword_init: true) do
    def to_s
      "Order #{order_id}: #{status} #{message}".strip
    end
  end

  SPLIT = 'split'.freeze
  WOULD_SPLIT = 'would split'.freeze
  SKIPPED = 'skipped'.freeze

  def self.candidate_orders
    aggregated_order_ids = TicketLineItem.joins(:ticket_class)
                                         .where(seat_assignment_id: nil, ticket_classes: { holds_seats: true })
                                         .where('line_items.ticket_count > 0')
                                         .select(:order_id)
    TicketOrder.joins(performance: :production)
               .where(status: Order::HOLDING_SEAT_STATUSES, id: aggregated_order_ids)
               .where.not(productions: { seat_map_id: nil })
               .where(performances: { performance_date: Date.current.. })
  end

  def initialize(order, dry_run: false)
    @order = order
    @dry_run = dry_run
  end

  def call
    plan = build_plan
    mismatch = plan.find { |entry| entry[:seats].size != entry[:ticket_count] }
    return skipped(mismatch) if mismatch

    pairs = plan.flat_map { |entry| assign_seats(entry) }
    apply!(pairs) unless @dry_run
    result(@dry_run ? WOULD_SPLIT : SPLIT, pairs.size, describe(plan))
  end

  private

  # One entry per ticket class: its aggregates and the order's seats of that
  # class with no line item linked.
  def build_plan
    linked_ids = @order.ticket_line_items.map(&:seat_assignment_id).compact
    unlinked = @order.seats.reject { |sa| linked_ids.include?(sa.id) }
    @order.legacy_seat_aggregates.group_by(&:ticket_class_id).map do |ticket_class_id, aggregates|
      { ticket_class_id: ticket_class_id,
        aggregates: aggregates,
        ticket_count: aggregates.sum(&:ticket_count),
        seats: unlinked.select { |sa| sa.ticket_class_id == ticket_class_id }.sort_by(&:id) }
    end
  end

  def assign_seats(entry)
    seats = entry[:seats].dup
    entry[:aggregates].flat_map do |aggregated|
      seats.shift(aggregated.ticket_count).map { |sa| [aggregated, sa] }
    end
  end

  # A seat without its own price keeps the aggregate's, so order totals do
  # not change.
  def apply!(pairs)
    TicketOrder.transaction do
      pairs.each do |aggregated, sa|
        @order.split_seat_from_aggregate!(aggregated, sa, price_override: sa.price_override || aggregated.price_override)
      end
    end
  end

  def skipped(entry)
    message = "ticket class #{entry[:ticket_class_id]} has ticket_count #{entry[:ticket_count]} " \
              "but #{entry[:seats].size} unlinked seat(s)"
    Rails.logger.warn("legacy_line_items:split_aggregates: order #{@order.id} skipped, #{message}")
    result(SKIPPED, 0, message)
  end

  def describe(plan)
    plan.map { |entry| "class #{entry[:ticket_class_id]} x#{entry[:ticket_count]}" }.join(', ')
  end

  def result(status, seats_split, message)
    Result.new(order_id: @order.id, status: status, seats_split: seats_split, message: message)
  end
end
