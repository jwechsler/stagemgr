require 'rails_helper'
require Rails.root.join('db/migrate/20261001110000_repoint_reseated_seat_line_items')

RSpec.describe RepointReseatedSeatLineItems do
  def migrate!
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  def tlis(order)
    TicketLineItem.where(order_id: order.id).order(:id)
  end

  def per_seat_order(status: Order::PROCESSED)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    seat_class = order.ticket_line_items.first.ticket_class
    order.ticket_line_items.to_a.each(&:destroy)
    order.seats.reload.sort_by(&:id).each do |sa|
      sa.update_columns(status: SeatAssignment::ASSIGNED, order_id: order.id)
      order.ticket_line_items.create!(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: sa.id)
    end
    order.update_columns(status: status)
    order.reload
  end

  def free_seat(order)
    order.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first
  end

  # The pre-fix Change Seating commit: the new seat is Assigned to the order
  # with class 0, the old seat is Available but keeps order_id and class, and
  # the line item still points at the old seat.
  def reseat_the_old_way(order, old_seat)
    new_seat = free_seat(order)
    new_seat.update_columns(status: SeatAssignment::ASSIGNED, order_uuid: order.uuid, order_id: order.id,
                            ticket_class_id: 0)
    old_seat.update_columns(status: SeatAssignment::AVAILABLE, order_uuid: nil)
    new_seat
  end

  it 'repoints the stale line item to the seat the order holds and cleans the released seat' do
    order = per_seat_order
    old_seat, = order.seats.sort_by(&:id)
    li = TicketLineItem.find_by(seat_assignment_id: old_seat.id)
    new_seat = reseat_the_old_way(order, old_seat)

    migrate!

    expect(li.reload.seat_assignment_id).to eq(new_seat.id)
    expect(new_seat.reload).to have_attributes(ticket_class_id: li.ticket_class_id, order_id: order.id)
    expect(old_seat.reload).to have_attributes(order_id: nil, ticket_class_id: nil, price_override: nil)
    payload = TicketOrder.find(order.id).send(:build_tktprint_payload, 'batch', 1)
    expect(payload[:tickets_attributes].pluck(:seat)).to include(new_seat.seat.location)
  end

  it 'repoints a past performance order' do
    order = per_seat_order
    order.performance.update_columns(performance_date: Date.current - 30)
    old_seat, = order.seats.sort_by(&:id)
    li = TicketLineItem.find_by(seat_assignment_id: old_seat.id)
    new_seat = reseat_the_old_way(order, old_seat)

    migrate!

    expect(li.reload.seat_assignment_id).to eq(new_seat.id)
  end

  it 'untangles two orders that each point at a seat the other now holds' do
    first = per_seat_order
    a_seat = first.seats.min_by(&:id)
    a_li = TicketLineItem.find_by(seat_assignment_id: a_seat.id)
    second = FactoryBot.create(:ticket_order, :reserved_seating, performance: first.performance)
    second.update_columns(status: Order::PROCESSED)
    b_seat = free_seat(first)
    b_seat.update_columns(status: SeatAssignment::ASSIGNED, order_uuid: second.uuid, order_id: second.id,
                          ticket_class_id: a_li.ticket_class_id)
    b_li = second.ticket_line_items.create!(ticket_class: a_li.ticket_class, ticket_count: 1,
                                            seat_assignment_id: b_seat.id)
    # The two orders traded seats; neither line item followed.
    a_seat.update_columns(order_uuid: second.uuid, order_id: second.id)
    b_seat.update_columns(order_uuid: first.uuid, order_id: first.id)

    migrate!

    expect(a_li.reload.seat_assignment_id).to eq(b_seat.id)
    expect(b_li.reload.seat_assignment_id).to eq(a_seat.id)
  end

  it 'clears the stale link and leaves the order for review when counts do not match' do
    order = per_seat_order
    old_seat, = order.seats.sort_by(&:id)
    li = TicketLineItem.find_by(seat_assignment_id: old_seat.id)
    old_seat.update_columns(status: SeatAssignment::AVAILABLE, order_uuid: nil)

    expect { described_class.new.up }.to output(/order #{order.id}: MANUAL REVIEW/).to_stdout
    expect(li.reload.seat_assignment_id).to be_nil
    expect do
      FactoryBot.create(:ticket_order, :reserved_seating, performance: order.performance)
                .ticket_line_items.create!(ticket_class: li.ticket_class, ticket_count: 1,
                                           seat_assignment_id: old_seat.id)
    end.not_to raise_error
  end

  it 'leaves an already correct order untouched' do
    order = per_seat_order
    before = tlis(order).pluck(:id, :seat_assignment_id)
    seats = SeatAssignment.where(order_uuid: order.uuid).order(:id).pluck(:id, :ticket_class_id, :order_id, :updated_at)

    migrate!

    expect(tlis(order).pluck(:id, :seat_assignment_id)).to eq(before)
    expect(SeatAssignment.where(order_uuid: order.uuid).order(:id)
                         .pluck(:id, :ticket_class_id, :order_id, :updated_at)).to eq(seats)
  end

  it 'leaves a Change Seating in progress alone' do
    order = per_seat_order
    old_seat, = order.seats.sort_by(&:id)
    old_seat.update_columns(status: SeatAssignment::RELEASING)
    before = tlis(order).pluck(:id, :seat_assignment_id)

    migrate!

    expect(tlis(order).pluck(:id, :seat_assignment_id)).to eq(before)
  end

  it 'leaves a refunded order untouched' do
    order = per_seat_order(status: Order::REFUNDED)
    old_seat, = order.seats.sort_by(&:id)
    reseat_the_old_way(order, old_seat)

    expect { migrate! }.not_to(change { tlis(order).pluck(:seat_assignment_id) })
  end

  it 'finds nothing to do when run again' do
    order = per_seat_order
    reseat_the_old_way(order, order.seats.min_by(&:id))
    migrate!
    linked = tlis(order).pluck(:id, :seat_assignment_id)

    expect { described_class.new.up }
      .to output(/0 order\(s\): repointed 0 line item\(s\).*on 0 Available seat\(s\)/).to_stdout
    expect(tlis(order).pluck(:id, :seat_assignment_id)).to eq(linked)
  end
end
