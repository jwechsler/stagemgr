class RepointReseatedSeatLineItems < ActiveRecord::Migration[6.1]
  # Before SeatReseat, Change Seating committed a reseat by flipping seat
  # statuses only: the new seats became Assigned and the old ones Available,
  # but each per-seat TicketLineItem kept its seat_assignment_id on the OLD
  # seat. The ticket printed with a blank seat (tktprint resolves the seat by
  # that FK) and the released seat could not be resold: the next buyer's line
  # item hit index_line_items_on_seat_assignment_id. Reseats also left the old
  # seat's order_id, ticket_class_id and price_override behind.
  #
  # Targets are found when the migration runs: live ticket orders (Processed,
  # Fulfilled, Hold; any performance date) with a line item on a seat the
  # order does not hold, i.e. the seat's order_uuid is not the order's, or the
  # seat is not Assigned / Held / Releasing. (Held and Releasing under the
  # order's own uuid are an edit or Change Seating in progress and are left
  # alone.) Per order, in its own transaction:
  #   - the order's free seats are its Assigned seats that none of its own
  #     line items references (a seat referenced only by ANOTHER order's stale
  #     line item counts as free; that stale link is cleared when taken);
  #   - counts match: each stale line item moves to a free seat, preferring
  #     one that already carries its class, otherwise in location order, and
  #     the seat takes the line item's class, donation price and the order id;
  #   - counts differ: the stale links are cleared, so the released seat stops
  #     blocking resale, and the order is logged for manual review.
  # Finally, Available seats with no order_uuid shed a stale order_id, class
  # and price override. Nothing reads those columns on an Available seat
  # except Performance#remove_illegal_seat_assignments, which may then delete
  # it like any other unsold seat of a removed seat-map seat.
  #
  # Rerunning finds nothing: every live line item then points at a held seat
  # or at none. Self-contained tables, no app models.
  class LineItemRow < ActiveRecord::Base
    self.table_name = 'line_items'
    self.inheritance_column = nil
  end

  class SeatAssignmentRow < ActiveRecord::Base
    self.table_name = 'seat_assignments'
  end

  LIVE_STATUSES = %w[Processed Fulfilled Hold].freeze
  HELD_STATUSES = %w[Assigned Held Releasing].freeze
  ASSIGNED = 'Assigned'.freeze
  AVAILABLE = 'Available'.freeze
  DONATION = 'Donation'.freeze

  def up
    totals = { orders: 0, repointed: 0, nulled: 0, review: 0 }
    stale_line_items.group_by { |li| li['order_id'] }.each do |order_id, items|
      totals[:orders] += 1
      repaired = repair_order(order_id, items.first['uuid'], items)
      if repaired
        totals[:repointed] += items.size
      else
        totals[:nulled] += items.size
        totals[:review] += 1
      end
    end
    cleared = clear_released_seats
    say "#{totals[:orders]} order(s): repointed #{totals[:repointed]} line item(s), " \
        "cleared #{totals[:nulled]} stale link(s) on #{totals[:review]} order(s) for manual review; " \
        "cleared stale order data on #{cleared} Available seat(s)"
  end

  # Nothing to restore: the old state was line items pointing at seats their
  # orders had given up, which is exactly what this repairs.
  def down; end

  private

  def stale_line_items
    select_rows(<<~SQL.squish, LIVE_STATUSES, HELD_STATUSES)
      SELECT li.id, li.order_id, li.ticket_class_id, li.price_override, tc.ticket_type, o.uuid
        FROM line_items li
        JOIN orders o ON o.id = li.order_id AND o.type = 'TicketOrder'
        JOIN seat_assignments sa ON sa.id = li.seat_assignment_id
        LEFT JOIN ticket_classes tc ON tc.id = li.ticket_class_id
       WHERE li.type = 'TicketLineItem' AND o.status IN (?)
         AND (sa.order_uuid IS NULL OR sa.order_uuid <> o.uuid OR sa.status NOT IN (?))
       ORDER BY li.order_id, li.id
    SQL
  end

  # True when every stale line item was repointed, false when cleared instead.
  def repair_order(order_id, order_uuid, items)
    seats = free_seats(order_id, order_uuid)
    transaction do
      LineItemRow.where(id: items.pluck('id')).update_all(seat_assignment_id: nil)
      next false if seats.size != items.size

      pair(items, seats).each { |li, sa| link(order_id, li, sa) }
      true
    end.tap do |repaired|
      say order_report(order_id, items, seats, repaired), true
    end
  end

  def order_report(order_id, items, seats, repaired)
    if repaired
      "order #{order_id}: repointed #{items.size} line item(s) to #{seats.pluck('location').join(', ')}"
    else
      "order #{order_id}: MANUAL REVIEW, #{items.size} stale line item(s) but #{seats.size} free held " \
        'seat(s); stale seat links cleared'
    end
  end

  def free_seats(order_id, order_uuid)
    select_rows(<<~SQL.squish, order_uuid, ASSIGNED, order_id)
      SELECT sa.id, sa.ticket_class_id, s.location FROM seat_assignments sa
        JOIN seats s ON s.id = sa.seat_id
       WHERE sa.order_uuid = ? AND sa.status = ?
         AND NOT EXISTS (SELECT 1 FROM line_items li WHERE li.seat_assignment_id = sa.id AND li.order_id = ?)
       ORDER BY s.location, sa.id
    SQL
  end

  # A seat already carrying a line item's class goes to that line item first;
  # the rest pair in order (line items by id, seats by location then id).
  def pair(items, seats)
    pool = seats.dup
    exact = items.map do |li|
      match = pool.find { |sa| sa['ticket_class_id'] == li['ticket_class_id'] }
      [li, match && pool.delete(match)]
    end
    exact.map { |li, sa| [li, sa || pool.shift] }
  end

  def link(order_id, item, seat)
    taken = LineItemRow.where(seat_assignment_id: seat['id']).where.not(id: item['id'])
    taken.pluck(:id, :order_id).each do |id, other_order|
      say "order #{order_id}: took seat #{seat['location']} from stale line item #{id} (order #{other_order})", true
    end
    taken.update_all(seat_assignment_id: nil)
    LineItemRow.where(id: item['id']).update_all(seat_assignment_id: seat['id'])
    price_override = item['ticket_type'] == DONATION ? item['price_override'] : nil
    SeatAssignmentRow.where(id: seat['id']).update_all(ticket_class_id: item['ticket_class_id'],
                                                       price_override: price_override, order_id: order_id)
  end

  def clear_released_seats
    SeatAssignmentRow.where(status: AVAILABLE, order_uuid: nil).where.not(order_id: nil)
                     .update_all(order_id: nil, ticket_class_id: nil, price_override: nil)
  end

  def select_rows(sql, *binds)
    connection.select_all(ActiveRecord::Base.sanitize_sql_array([sql, *binds])).to_a
  end
end
