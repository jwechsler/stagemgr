require 'rails_helper'

# Change Seating (admin, reseating.js) holds replacement seats TEMPORARY with
# no class, marks the seats being given up RELEASING, then commits. The commit
# must move each per-seat TicketLineItem's seat FK onto its replacement seat
# and carry the class over; otherwise the ticket prints with a blank seat and
# the released seat cannot be resold (index_line_items_on_seat_assignment_id).
#
# Regression for order 337185: TLI 773651 kept seat 97025 (released,
# Available) while the order held 97026.
RSpec.describe 'SeatAssignment.reseating_commit' do
  def per_seat_order
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    seat_class = order.ticket_line_items.first.ticket_class
    order.ticket_line_items.to_a.each(&:destroy)
    order.seats.reload.sort_by(&:id).each do |sa|
      sa.update_columns(status: SeatAssignment::ASSIGNED, order_id: order.id)
      order.ticket_line_items.create!(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: sa.id)
    end
    order.update_columns(status: Order::PROCESSED)
    order.reload
  end

  def seats_of(order)
    order.seats.reload.sort_by(&:id)
  end

  def line_item_on(seat)
    TicketLineItem.find_by(seat_assignment_id: seat.id)
  end

  def free_seats(order, count)
    order.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE)
         .includes(:seat).sort_by { |sa| [sa.seat.location, sa.id] }.first(count)
  end

  # What the admin seat map does: release (reseating: true) then a classless reserve.
  def release!(order, seat)
    seat.reload.begin_release_from_order(order.uuid)
  end

  def hold!(order, seat)
    seat.reload.assign_to_order(order.uuid, 999, 0, nil)
  end

  def printed_seats(order)
    TicketOrder.find(order.id).send(:build_tktprint_payload, 'batch', 1)[:tickets_attributes].pluck(:seat)
  end

  it 'moves the line item seat FK onto the replacement seat and carries class and order over' do
    order = per_seat_order
    old_seat, kept_seat = seats_of(order)
    moving = line_item_on(old_seat)
    kept = line_item_on(kept_seat)
    old_seat.update_columns(price_override: 12.5)
    new_seat = free_seats(order, 1).first
    release!(order, old_seat)
    hold!(order, new_seat)

    expect(SeatAssignment.reseating_commit(order.uuid)).to eq('success')

    expect(moving.reload.seat_assignment_id).to eq(new_seat.id)
    expect(kept.reload.seat_assignment_id).to eq(kept_seat.id)
    expect(new_seat.reload).to have_attributes(status: SeatAssignment::ASSIGNED, order_uuid: order.uuid, order_id: order.id,
                                               ticket_class_id: moving.ticket_class_id, price_override: 12.5)
    expect(old_seat.reload).to have_attributes(status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil,
                                               ticket_class_id: nil, price_override: nil)
  end

  it 'prints the new seat location' do
    order = per_seat_order
    old_seat, kept_seat = seats_of(order)
    new_seat = free_seats(order, 1).first
    release!(order, old_seat)
    hold!(order, new_seat)

    SeatAssignment.reseating_commit(order.uuid)

    expect(printed_seats(order)).to match_array([new_seat.seat.location, kept_seat.seat.location])
  end

  it 'leaves the released seat resellable' do
    order = per_seat_order
    old_seat, = seats_of(order)
    seat_class = line_item_on(old_seat).ticket_class
    release!(order, old_seat)
    hold!(order, free_seats(order, 1).first)
    SeatAssignment.reseating_commit(order.uuid)

    buyer = FactoryBot.create(:ticket_order, :reserved_seating, performance: order.performance)
    expect do
      buyer.ticket_line_items.create!(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: old_seat.id)
    end.not_to raise_error
  end

  it 'only touches the seats that changed in a partial reseat' do
    order = per_seat_order
    old_seat, kept_seat = seats_of(order)
    kept_attrs = kept_seat.reload.attributes.slice('status', 'order_id', 'ticket_class_id', 'order_uuid')
    kept = line_item_on(kept_seat)
    release!(order, old_seat)
    hold!(order, free_seats(order, 1).first)

    SeatAssignment.reseating_commit(order.uuid)

    expect(kept.reload.seat_assignment_id).to eq(kept_seat.id)
    expect(kept_seat.reload.attributes.slice(*kept_attrs.keys)).to eq(kept_attrs)
  end

  it 'keeps the line item and class on a releasing seat that was picked again' do
    order = per_seat_order
    seat, = seats_of(order)
    li = line_item_on(seat)
    release!(order, seat)
    hold!(order, seat)

    expect(SeatAssignment.reseating_commit(order.uuid)).to eq('success')
    expect(li.reload.seat_assignment_id).to eq(seat.id)
    expect(seat.reload).to have_attributes(status: SeatAssignment::ASSIGNED, ticket_class_id: li.ticket_class_id)
  end

  it 'swaps two seats of the same order without tripping the unique index' do
    order = per_seat_order
    first, second = seats_of(order)
    first_li = line_item_on(first)
    second_li = line_item_on(second)
    new_seats = free_seats(order, 2)
    [first, second].each { |sa| release!(order, sa) }
    new_seats.each { |sa| hold!(order, sa) }

    expect(SeatAssignment.reseating_commit(order.uuid)).to eq('success')
    expect([first_li.reload, second_li.reload].map(&:seat_assignment_id)).to match_array(new_seats.map(&:id))
    expect(TicketLineItem.where(seat_assignment_id: [first.id, second.id])).to be_empty
  end

  it 'carries the class to the new seat for a legacy aggregated line item mixed with a linked one' do
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    legacy = order.ticket_line_items.first
    legacy.update_columns(ticket_count: 1)
    legacy_seat, linked_seat = seats_of(order)
    linked_class = FactoryBot.create(:ticket_class, production: order.performance.production, class_code: 'LINK')
    linked_seat.update_columns(ticket_class_id: linked_class.id)
    linked = order.ticket_line_items.create!(ticket_class: linked_class, ticket_count: 1,
                                             seat_assignment_id: linked_seat.id)
    order.update_columns(status: Order::PROCESSED)
    new_seats = free_seats(order, 2)
    [legacy_seat, linked_seat].each { |sa| release!(order, sa) }
    new_seats.each { |sa| hold!(order, sa) }

    expect(SeatAssignment.reseating_commit(order.uuid)).to eq('success')

    expect(new_seats.map(&:id)).to include(linked.reload.seat_assignment_id)
    expect(legacy.reload.seat_assignment_id).to be_nil
    expect(SeatAssignment.where(id: new_seats.map(&:id)).pluck(:ticket_class_id))
      .to match_array([legacy.ticket_class_id, linked_class.id])
    expect(printed_seats(order)).to match_array(new_seats.map { |sa| sa.seat.location })
  end

  it 'pairs a zone-specific class with a replacement seat in its own zone' do
    order = per_seat_order
    production = order.performance.production
    first, second = seats_of(order).sort_by { |sa| [sa.seat.location, sa.id] }
    zone_a = FactoryBot.create(:ticket_class, production: production, class_code: 'ZA', zone_id: 'A')
    zone_b = FactoryBot.create(:ticket_class, production: production, class_code: 'ZB', zone_id: 'B')
    line_item_on(first).update_columns(ticket_class_id: zone_a.id)
    line_item_on(second).update_columns(ticket_class_id: zone_b.id)
    first.update_columns(ticket_class_id: zone_a.id)
    second.update_columns(ticket_class_id: zone_b.id)
    second.seat.update!(zone: 'B')
    # The replacement seat that sorts first is in zone B, so pairing in
    # location order alone would put the zone A ticket there.
    early, late = free_seats(order, 2)
    early.seat.update!(zone: 'B')
    late.seat.update!(zone: 'A')
    [first, second].each { |sa| release!(order, sa) }
    [early, late].each { |sa| hold!(order, sa) }

    expect(SeatAssignment.reseating_commit(order.uuid)).to eq('success')
    expect(line_item_on(late).ticket_class_id).to eq(zone_a.id)
    expect(line_item_on(early).ticket_class_id).to eq(zone_b.id)
    expect(late.reload.ticket_class_id).to eq(zone_a.id)
    expect(early.reload.ticket_class_id).to eq(zone_b.id)
  end

  it 'leaves line item FKs untouched on rollback' do
    order = per_seat_order
    old_seat, = seats_of(order)
    before = TicketLineItem.where(order_id: order.id).pluck(:id, :seat_assignment_id)
    new_seat = free_seats(order, 1).first
    release!(order, old_seat)
    hold!(order, new_seat)

    SeatAssignment.reseating_rollback(order.uuid)

    expect(TicketLineItem.where(order_id: order.id).pluck(:id, :seat_assignment_id)).to eq(before)
    expect(old_seat.reload).to have_attributes(status: SeatAssignment::ASSIGNED, order_id: order.id)
    expect(new_seat.reload.status).to eq(SeatAssignment::AVAILABLE)
  end
end
