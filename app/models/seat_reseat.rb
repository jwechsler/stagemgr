# Change Seating (admin seat map, reseating.js): the order marks the seats it
# is giving up RELEASING and holds replacements TEMPORARY with no class.
# Before SeatAssignment.reseating_commit flips those statuses, this pairs
# each releasing seat with a replacement and moves what belongs to the
# ticket rather than the chair: the per-seat TicketLineItem's seat FK, the
# ticket class, the seat price override and the order id.
#
# Pairing honours zoned pricing exactly as reseating_zone_conflict counts
# it: a releasing seat's class must be sellable in the replacement's zone.
# Zone-specific classes choose first (each takes the first free replacement
# in its zone), then wildcard or classless ones take what is left; within
# each group seats go in location order, so the result is deterministic.
# Given the conflict check passed, every releasing seat finds a partner.
class SeatReseat
  Pair = Struct.new(:old_seat, :new_seat, :line_item)

  def initialize(order_uuid)
    @order_uuid = order_uuid
    @order = Order.find_by(uuid: order_uuid)
  end

  # The class each releasing seat must be placed with: its linked line
  # item's class, else (legacy aggregated orders, no seat FK) the seat's own.
  def release_classes
    releasing.map { |sa| class_for(sa) }
  end

  # Writes the pairing. Returns nil, or a message when a seat carrying a
  # line item has no replacement (nothing is written in that case).
  def apply!
    pairs = pair
    stranded = pairs.select { |p| p.new_seat.nil? && p.line_item }
    return "Unable to match seat(s) #{stranded.map { |p| p.old_seat.seat.location }.join(', ')}" if stranded.any?

    move_line_items(pairs.select { |p| p.new_seat && p.line_item })
    pairs.select(&:new_seat).each { |p| carry_seat_columns(p) }
    restore_repicked_classes
    nil
  end

  private

  def releasing
    @releasing ||= in_location_order(SeatAssignment.where(order_uuid: @order_uuid, status: SeatAssignment::RELEASING)
                                                   .includes(:seat, :ticket_class))
  end

  def incoming
    @incoming ||= in_location_order(SeatAssignment.where(order_uuid: @order_uuid, status: SeatAssignment::TEMPORARY).includes(:seat))
  end

  def in_location_order(scope)
    scope.to_a.sort_by { |sa| [sa.seat.location.to_s, sa.id] }
  end

  # This order's line items on any seat taking part in the reseat, by seat id.
  def line_items
    @line_items ||= if @order.nil?
                      {}
                    else
                      TicketLineItem.includes(:ticket_class)
                                    .where(order_id: @order.id,
                                           seat_assignment_id: (releasing + incoming).map(&:id))
                                    .index_by(&:seat_assignment_id)
                    end
  end

  def class_for(seat)
    line_items[seat.id]&.ticket_class || seat.ticket_class
  end

  def class_id_for(seat)
    line_items[seat.id]&.ticket_class_id || seat.ticket_class_id
  end

  # Replacements no line item points at. A TEMPORARY seat that already has
  # this order's line item is a releasing seat picked again; it stays put.
  def free_incoming
    taken = TicketLineItem.where(seat_assignment_id: incoming.map(&:id)).pluck(:seat_assignment_id)
    incoming.reject { |sa| taken.include?(sa.id) }
  end

  def pair
    pool = free_incoming
    specific, open = releasing.partition { |sa| zone_specific?(class_for(sa)) }
    (specific + open).map do |sa|
      ticket_class = class_for(sa)
      partner = pool.find { |n| ticket_class.nil? || ticket_class.sellable_for_zone?(n.seat.zone) }
      pool.delete(partner)
      Pair.new(sa, partner, line_items[sa.id])
    end
  end

  def zone_specific?(ticket_class)
    ticket_class.present? && ticket_class.zone_id != ZoneMatchable::WILDCARD
  end

  # Clear every moving FK before setting any, so the unique index on
  # line_items.seat_assignment_id never sees two rows on one seat.
  def move_line_items(moving)
    return if moving.empty?

    now = Time.current
    TicketLineItem.where(id: moving.map { |p| p.line_item.id }).update_all(seat_assignment_id: nil, updated_at: now)
    moving.each do |p|
      TicketLineItem.where(id: p.line_item.id).update_all(seat_assignment_id: p.new_seat.id, updated_at: now)
    end
  end

  def carry_seat_columns(pair)
    SeatAssignment.where(id: pair.new_seat.id).update_all(
      ticket_class_id: class_id_for(pair.old_seat), price_override: pair.old_seat.price_override,
      order_id: @order&.id || pair.old_seat.order_id, updated_at: Time.current
    )
  end

  # A classless reserve on a seat writes class 0 onto it; a releasing seat
  # picked again takes its line item's class back.
  def restore_repicked_classes
    incoming.each do |sa|
      li = line_items[sa.id]
      next if li.nil? || li.ticket_class_id == sa.ticket_class_id

      SeatAssignment.where(id: sa.id).update_all(ticket_class_id: li.ticket_class_id, updated_at: Time.current)
    end
  end
end
