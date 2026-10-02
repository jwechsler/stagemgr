class ReleaseSeatsOfReleasedOrders < ActiveRecord::Migration[6.1]
  # A refund or unclaim cleared the seat link only on line items pointing at a
  # seat the order still held. A link to a seat the order had given up earlier
  # (pre-8f4dc8987 Change Seating left these behind) survived the release and,
  # being the only row index_line_items_on_seat_assignment_id allows on that
  # seat, blocked its next sale. The release also skipped orders whose
  # production had lost its seat map, so their seats stayed Assigned. Releases
  # now go through SeatRelease; this repairs what came before.
  #
  # Targets are found when the migration runs, for ticket orders in a status
  # that holds no seats (Refunded, Unclaimed, Canceled, Exchanged, Split; none
  # of these legitimately holds a seat: the exchange source is Releasing only
  # in memory and is released before it is saved Exchanged):
  #   1. every seat link on their line items is cleared (rows kept);
  #   2. every seat still held under their uuid (Assigned / Held / Releasing)
  #      becomes Available with order id, class, price override and
  #      accessibility cleared;
  #   3. a seat whose stale link pointed at it but which is Assigned to a live
  #      order (Processed / Fulfilled / Hold) may have left that order's own
  #      line item without a seat. When the live order's unlinked one-ticket
  #      seat-holding line items match its Assigned seats that no line item
  #      references, one for one, they are paired (class match first, then
  #      location order) and each seat takes its line item's class, donation
  #      price and the order id. Otherwise the order is logged for review.
  #   4. a seat still held by any ticket order on a performance other than the
  #      order's own (moving an order to another performance never released
  #      the old seats: unassign_seats_when_performance_changes passed the
  #      order, not its uuid) is released the same way, and any line item
  #      link to it is cleared.
  # Every step reports per order and per status. Rerunning finds nothing.
  # Self-contained tables, no app models.
  class LineItemRow < ActiveRecord::Base
    self.table_name = 'line_items'
    self.inheritance_column = nil
  end

  class SeatAssignmentRow < ActiveRecord::Base
    self.table_name = 'seat_assignments'
  end

  RELEASED_STATUSES = %w[Refunded Unclaimed Canceled Exchanged Split].freeze
  LIVE_STATUSES = %w[Processed Fulfilled Hold].freeze
  HELD_SEAT_STATUSES = %w[Assigned Held Releasing].freeze
  ASSIGNED = 'Assigned'.freeze
  AVAILABLE = 'Available'.freeze
  DONATION = 'Donation'.freeze

  def up
    links = released_order_links
    displaced = links.select { |row| row['seat_status'] == ASSIGNED && LIVE_STATUSES.include?(row['holder_status']) }
    clear_links(links)
    release_held_seats
    relink_displaced(displaced)
    release_other_performance_seats
  end

  # Nothing to restore: the old state was released orders still claiming
  # seats, which is exactly what this repairs.
  def down; end

  private

  def released_order_links
    select_rows(<<~SQL.squish, RELEASED_STATUSES)
      SELECT li.id, li.order_id, o.status, sa.status AS seat_status, s.location,
             holder.id AS holder_id, holder.status AS holder_status,
             CASE WHEN sa.order_uuid = o.uuid THEN 'held'
                  WHEN holder.id IS NULL THEN 'free'
                  ELSE 'other' END AS kind
        FROM line_items li
        JOIN orders o ON o.id = li.order_id AND o.type = 'TicketOrder'
        JOIN seat_assignments sa ON sa.id = li.seat_assignment_id
        JOIN seats s ON s.id = sa.seat_id
        LEFT JOIN orders holder ON holder.uuid = sa.order_uuid AND holder.id <> o.id
       WHERE li.seat_assignment_id IS NOT NULL AND o.status IN (?)
       ORDER BY o.status, li.order_id, li.id
    SQL
  end

  def clear_links(links)
    links.group_by { |row| row['order_id'] }.each do |order_id, rows|
      kinds = rows.map { |row| row['kind'] }.tally.map { |kind, n| "#{n} #{kind}" }.join(', ')
      say "order #{order_id} [#{rows.first['status']}]: cleared #{rows.size} seat link(s) (#{kinds})", true
    end
    LineItemRow.where(id: links.pluck('id')).update_all(seat_assignment_id: nil)
    say "cleared seat links: #{per_status(links)}"
  end

  def release_held_seats
    seats = select_rows(<<~SQL.squish, RELEASED_STATUSES, HELD_SEAT_STATUSES)
      SELECT sa.id, o.id AS order_id, o.status FROM seat_assignments sa
        JOIN orders o ON o.uuid = sa.order_uuid AND o.type = 'TicketOrder'
       WHERE o.status IN (?) AND sa.status IN (?)
       ORDER BY o.status, o.id, sa.id
    SQL
    seats.group_by { |row| row['order_id'] }.each do |order_id, rows|
      say "order #{order_id} [#{rows.first['status']}]: released #{rows.size} held seat(s)", true
    end
    SeatAssignmentRow.where(id: seats.pluck('id')).update_all(
      status: AVAILABLE, order_uuid: nil, order_id: nil, ticket_class_id: nil, price_override: nil, accessibility: nil
    )
    say "released held seats: #{per_status(seats)}"
  end

  def release_other_performance_seats
    seats = select_rows(<<~SQL.squish, HELD_SEAT_STATUSES)
      SELECT sa.id, o.id AS order_id, o.status FROM seat_assignments sa
        JOIN orders o ON o.uuid = sa.order_uuid AND o.type = 'TicketOrder'
       WHERE sa.status IN (?) AND sa.performance_id <> o.performance_id
       ORDER BY o.status, o.id, sa.id
    SQL
    seats.group_by { |row| row['order_id'] }.each do |order_id, rows|
      say "order #{order_id} [#{rows.first['status']}]: released #{rows.size} seat(s) on another performance", true
    end
    ids = seats.pluck('id')
    LineItemRow.where(seat_assignment_id: ids).update_all(seat_assignment_id: nil)
    SeatAssignmentRow.where(id: ids).update_all(
      status: AVAILABLE, order_uuid: nil, order_id: nil, ticket_class_id: nil, price_override: nil, accessibility: nil
    )
    say "released seats held on another performance: #{per_status(seats)}"
  end

  def per_status(rows)
    return 'none' if rows.empty?

    rows.group_by { |row| row['status'] }.map do |status, group|
      "#{status} #{group.size} on #{group.map { |row| row['order_id'] }.uniq.size} order(s)"
    end.join('; ')
  end

  def relink_displaced(displaced)
    totals = { linked: 0, review: 0 }
    displaced.map { |row| row['holder_id'] }.uniq.each do |order_id|
      linked = relink_order(order_id)
      if linked
        totals[:linked] += linked
      else
        totals[:review] += 1
      end
    end
    say "displaced live orders: #{totals[:linked]} line item(s) relinked, #{totals[:review]} order(s) for manual review"
  end

  # Returns the number of line items linked, or nil when left for review.
  def relink_order(order_id)
    items = unlinked_items(order_id)
    seats = unlinked_seats(order_id)
    if items.empty? || items.size != seats.size
      say "order #{order_id}: MANUAL REVIEW, lost a seat link to a released order; #{items.size} unlinked " \
          "line item(s), #{seats.size} unlinked Assigned seat(s)", true
      return nil
    end

    pair(items, seats).each { |item, seat| link(order_id, item, seat) }
    say "order #{order_id}: relinked #{items.size} line item(s) to #{seats.pluck('location').join(', ')}", true
    items.size
  end

  def unlinked_items(order_id)
    select_rows(<<~SQL.squish, order_id)
      SELECT li.id, li.ticket_class_id, li.price_override, tc.ticket_type FROM line_items li
        JOIN ticket_classes tc ON tc.id = li.ticket_class_id AND tc.holds_seats
       WHERE li.order_id = ? AND li.type = 'TicketLineItem' AND li.seat_assignment_id IS NULL
         AND li.ticket_count = 1
       ORDER BY li.id
    SQL
  end

  def unlinked_seats(order_id)
    select_rows(<<~SQL.squish, ASSIGNED, order_id)
      SELECT sa.id, sa.ticket_class_id, s.location FROM seat_assignments sa
        JOIN seats s ON s.id = sa.seat_id
        JOIN orders o ON o.uuid = sa.order_uuid
       WHERE sa.status = ? AND o.id = ?
         AND NOT EXISTS (SELECT 1 FROM line_items li WHERE li.seat_assignment_id = sa.id)
       ORDER BY s.location, sa.id
    SQL
  end

  # A seat already carrying a line item's class goes to that line item first;
  # the rest pair in order (line items by id, seats by location then id).
  def pair(items, seats)
    pool = seats.dup
    exact = items.map do |item|
      match = pool.find { |seat| seat['ticket_class_id'] == item['ticket_class_id'] }
      [item, match && pool.delete(match)]
    end
    exact.map { |item, seat| [item, seat || pool.shift] }
  end

  def link(order_id, item, seat)
    LineItemRow.where(id: item['id']).update_all(seat_assignment_id: seat['id'])
    price_override = item['ticket_type'] == DONATION ? item['price_override'] : nil
    SeatAssignmentRow.where(id: seat['id']).update_all(ticket_class_id: item['ticket_class_id'],
                                                       price_override: price_override, order_id: order_id)
  end

  def select_rows(sql, *binds)
    connection.select_all(ActiveRecord::Base.sanitize_sql_array([sql, *binds])).to_a
  end
end
