class RelinkSwappedSeatLineItems < ActiveRecord::Migration[6.1]
  # Before TicketOrder#replace_ticket_line_item, a class swap (pass redemption
  # at PROCESSED, ticket-class special offer) replaced each per-seat
  # TicketLineItem with one that had no seat_assignment_id. The order kept its
  # Assigned seat (still carrying the originally picked class), but no line
  # item pointed at it, so tktprint printed those tickets with a BLANK seat
  # (its class-matching fallback finds no seat of the pass class).
  #
  # This relinks upcoming orders only. Targets are found when the migration
  # runs: a reserved-seating order for a performance today or later, Processed
  # / Fulfilled / Hold, paid with a membership or flex pass or carrying a
  # special offer, whose seatless seat-holding line items (one ticket each)
  # number exactly as many as its Assigned seats that no line item references.
  # Each pair also gets the line item's class on the seat, as a swap now does.
  # Orders that do not fit exactly are logged and left alone. Rerunning finds
  # nothing: a relinked line item is no longer seatless.
  #
  # Self-contained tables, no app models, so later model changes cannot break it.
  class LineItemRow < ActiveRecord::Base
    self.table_name = 'line_items'
    self.inheritance_column = nil
  end

  class SeatAssignmentRow < ActiveRecord::Base
    self.table_name = 'seat_assignments'
  end

  ORDER_STATUSES = %w[Processed Fulfilled Hold].freeze
  # Explicit types: Payment STI subclass scopes are not trusted here.
  PASS_PAYMENT_TYPES = %w[MembershipPayment FlexPassPayment].freeze
  DONATION = 'Donation'.freeze
  ASSIGNED = 'Assigned'.freeze

  def up
    totals = { linked_orders: 0, linked_items: 0, skipped: 0 }
    candidate_orders.each do |order|
      outcome = relink_order(order)
      if outcome.is_a?(Integer)
        totals[:linked_orders] += 1
        totals[:linked_items] += outcome
      else
        totals[:skipped] += 1
        say "order #{order['id']}: skipped, #{outcome}", true
      end
    end
    say "relinked #{totals[:linked_items]} line items on #{totals[:linked_orders]} orders; " \
        "skipped #{totals[:skipped]} orders"
  end

  # Nothing to restore: the old state was line items detached from the seats
  # their orders hold, which is exactly what this repairs.
  def down; end

  private

  def candidate_orders
    select_rows(<<~SQL.squish, Date.current, ORDER_STATUSES, PASS_PAYMENT_TYPES)
      SELECT o.id, o.uuid FROM orders o
        JOIN performances pf ON pf.id = o.performance_id
        JOIN productions pr ON pr.id = pf.production_id
       WHERE o.type = 'TicketOrder'
         AND pf.performance_date >= ?
         AND pr.seat_map_id IS NOT NULL
         AND o.status IN (?)
         AND (EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id AND p.type IN (?))
              OR EXISTS (SELECT 1 FROM line_items so
                          WHERE so.order_id = o.id AND so.type = 'SpecialOfferLineItem'))
         AND EXISTS (#{seatless_items_sql('o.id')})
       ORDER BY o.id
    SQL
  end

  def seatless_items_sql(order_id_sql)
    <<~SQL.squish
      SELECT li.id, li.ticket_class_id, li.ticket_count, li.price_override, tc.ticket_type
        FROM line_items li JOIN ticket_classes tc ON tc.id = li.ticket_class_id
       WHERE li.order_id = #{order_id_sql} AND li.type = 'TicketLineItem'
         AND li.seat_assignment_id IS NULL AND tc.holds_seats = 1 AND li.ticket_count > 0
    SQL
  end

  # Returns the number of line items linked, or the reason the order was skipped.
  def relink_order(order)
    items = select_rows("#{seatless_items_sql('?')} ORDER BY li.id", order['id'])
    multi = items.count { |li| li['ticket_count'].to_i > 1 }
    return "#{multi} seatless line item(s) hold more than one ticket" if multi.positive?

    seats = free_seats(order['uuid'])
    return "#{items.size} seatless line item(s) but #{seats.size} unlinked seat(s)" if items.size != seats.size

    transaction { pair(items, seats).each { |li, sa| link(li, sa) } }
    say "order #{order['id']}: linked #{items.size} line item(s) to seat(s) " \
        "#{seats.pluck('location').join(', ')}", true
    items.size
  end

  def free_seats(order_uuid)
    select_rows(<<~SQL.squish, order_uuid, ASSIGNED)
      SELECT sa.id, sa.ticket_class_id, s.location FROM seat_assignments sa
        JOIN seats s ON s.id = sa.seat_id
       WHERE sa.order_uuid = ? AND sa.status = ?
         AND NOT EXISTS (SELECT 1 FROM line_items li WHERE li.seat_assignment_id = sa.id)
       ORDER BY s.location, sa.id
    SQL
  end

  # A seat still carrying a line item's class goes to that line item first;
  # the rest pair in order (line items by id, seats by location then id).
  def pair(items, seats)
    pool = seats.dup
    exact = items.map do |li|
      match = pool.find { |sa| sa['ticket_class_id'] == li['ticket_class_id'] }
      [li, match && pool.delete(match)]
    end
    exact.map { |li, sa| [li, sa || pool.shift] }
  end

  def link(item, seat)
    LineItemRow.where(id: item['id'], seat_assignment_id: nil).update_all(seat_assignment_id: seat['id'])
    price_override = item['ticket_type'] == DONATION ? item['price_override'] : nil
    SeatAssignmentRow.where(id: seat['id']).update_all(ticket_class_id: item['ticket_class_id'],
                                                       price_override: price_override)
  end

  def select_rows(sql, *binds)
    connection.select_all(ActiveRecord::Base.sanitize_sql_array([sql, *binds])).to_a
  end
end
