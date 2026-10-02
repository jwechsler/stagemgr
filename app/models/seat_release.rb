# Ends a ticket order's claim on its seats: refund, unclaim, cancel/destroy,
# conversion to a donation and the source side of an exchange all come here
# (TicketOrder#unassign_seats).
#
# - Every seat the order holds (Assigned, Held or Releasing under its uuid)
#   becomes Available and keeps nothing of the order: order uuid and id,
#   ticket class, price override and accessibility are cleared, as
#   SeatReseat's released seats are.
# - Every one of the order's line items lets go of its seat link, not just
#   the links to seats it still holds. A link left on a seat the order gave
#   up earlier (pre-8f4dc8987 Change Seating did this) is the only row the
#   unique index line_items.seat_assignment_id allows on that seat, so it
#   would block the seat's next sale. The line item rows themselves stay, for
#   the accounting history.
#
# With keep_performance_id, only seats on other performances are released and
# only the links to those seats are cleared: a live order moved to another
# performance (TicketOrder#unassign_seats_when_performance_changes) keeps what
# it has already picked on the new one.
#
# Writes with update_all, so no validation or callback can skip a seat.
class SeatRelease
  HELD_SEAT_STATUSES = [SeatAssignment::ASSIGNED, SeatAssignment::TEMPORARY, SeatAssignment::RELEASING].freeze

  # Order statuses that hold no seats; an order entering one is released as it
  # saves. Refund and unclaim rely on that. Exchange, split and conversion to
  # a donation hand off or release the seats first, so it then finds nothing.
  RELEASED_ORDER_STATUSES = [Order::REFUNDED, Order::UNCLAIMED, Order::CANCELED, Order::EXCHANGED, Order::SPLIT].freeze

  def self.releasing_status?(status)
    RELEASED_ORDER_STATUSES.include?(status)
  end

  def initialize(order, keep_performance_id: nil)
    @order = order
    @keep_performance_id = keep_performance_id
  end

  # Returns the number of seats released and seat links cleared.
  def apply!
    now = Time.current
    unlinked = clear_seat_links(now)
    released = release_seats(now)
    @order.seats.reset
    { seats: released, links: unlinked }
  end

  private

  def clear_seat_links(now)
    return 0 if @order.id.nil?

    links = TicketLineItem.where(order_id: @order.id).where.not(seat_assignment_id: nil)
    unless @keep_performance_id.nil?
      links = links.where(seat_assignment_id: SeatAssignment.where.not(performance_id: @keep_performance_id).select(:id))
    end
    links.update_all(seat_assignment_id: nil, updated_at: now)
  end

  def release_seats(now)
    return 0 if @order.uuid.blank?

    seats = SeatAssignment.where(order_uuid: @order.uuid, status: HELD_SEAT_STATUSES)
    seats = seats.where.not(performance_id: @keep_performance_id) unless @keep_performance_id.nil?
    seats.update_all(
      status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil, ticket_class_id: nil,
      price_override: nil, accessibility: nil, updated_at: now
    )
  end
end
