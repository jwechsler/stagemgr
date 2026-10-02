require 'rails_helper'
require Rails.root.join('db/migrate/20261001120000_release_seats_of_released_orders')

RSpec.describe ReleaseSeatsOfReleasedOrders do
  def migrate!
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
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

  def linked_seat_ids(order)
    TicketLineItem.where(order_id: order.id).where.not(seat_assignment_id: nil).order(:id).pluck(:seat_assignment_id)
  end

  # The pre-fix release: the order's seats are Available but its line items
  # still point at them.
  def stale_released(status)
    order = per_seat_order(status: status)
    seat_ids = order.seats.map(&:id)
    SeatAssignment.where(id: seat_ids).update_all(status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil)
    [order, seat_ids]
  end

  it 'clears an unclaimed order’s stale seat links' do
    order, = stale_released(Order::UNCLAIMED)
    migrate!
    expect(linked_seat_ids(order)).to be_empty
    expect(TicketLineItem.where(order_id: order.id).count).to eq(2)
  end

  it 'clears a refunded order’s stale seat links so the seat can be resold' do
    order, seat_ids = stale_released(Order::REFUNDED)
    ticket_class = order.ticket_line_items.first.ticket_class
    migrate!
    expect(linked_seat_ids(order)).to be_empty
    buyer = FactoryBot.create(:ticket_order, :reserved_seating, performance: order.performance)
    expect do
      buyer.ticket_line_items.create!(ticket_class: ticket_class, ticket_count: 1, seat_assignment_id: seat_ids.first)
    end.not_to raise_error
  end

  it 'releases seats a released order still holds and clears their links' do
    order = per_seat_order(status: Order::REFUNDED)
    seat_ids = order.seats.map(&:id)
    migrate!
    expect(linked_seat_ids(order)).to be_empty
    expect(SeatAssignment.where(id: seat_ids).pluck(:status, :order_uuid, :order_id, :ticket_class_id).uniq)
      .to eq([[SeatAssignment::AVAILABLE, nil, nil, nil]])
  end

  it 'leaves live orders untouched' do
    order = per_seat_order
    before = [linked_seat_ids(order),
              SeatAssignment.where(order_uuid: order.uuid).order(:id).pluck(:id, :status, :ticket_class_id, :updated_at)]
    migrate!
    expect([linked_seat_ids(order),
            SeatAssignment.where(order_uuid: order.uuid).order(:id)
                          .pluck(:id, :status, :ticket_class_id, :updated_at)]).to eq(before)
  end

  context 'when the stale link sat on a seat now Assigned to a live order' do
    # The refunded order's line item still points at a seat a live order
    # bought; the live order's own line item for that seat has no link.
    def displaced_pair(live_items: 1)
      refunded, seat_ids = stale_released(Order::REFUNDED)
      seat = SeatAssignment.find(seat_ids.first)
      ticket_class = refunded.ticket_line_items.first.ticket_class
      live = FactoryBot.create(:ticket_order, :reserved_seating, performance: refunded.performance)
      live.update_columns(status: Order::FULFILLED)
      seat.update_columns(status: SeatAssignment::ASSIGNED, order_uuid: live.uuid, order_id: live.id,
                          ticket_class_id: ticket_class.id)
      live_items.times { live.ticket_line_items.create!(ticket_class: ticket_class, ticket_count: 1) }
      [refunded, live, seat]
    end

    it 'relinks the live order’s line item to its seat' do
      refunded, live, seat = displaced_pair
      migrate!
      expect(linked_seat_ids(refunded)).to be_empty
      expect(linked_seat_ids(live)).to eq([seat.id])
      expect(seat.reload).to have_attributes(status: SeatAssignment::ASSIGNED, order_uuid: live.uuid)
    end

    it 'logs the live order for review when the counts do not match' do
      _, live, = displaced_pair(live_items: 2)
      expect { described_class.new.up }.to output(/order #{live.id}: MANUAL REVIEW/).to_stdout
      expect(linked_seat_ids(live)).to be_empty
    end
  end

  # The pre-fix performance change: the order moved, its old seats stayed held
  # under its uuid and its line items kept their links to them.
  it 'releases seats a live order still holds on a performance it moved away from' do
    order = per_seat_order
    old_seat_ids = order.seats.map(&:id)
    other = FactoryBot.create(:reserved_seating, production: order.performance.production,
                                                 performance_date: order.performance.performance_date + 1.day)
    order.update_columns(performance_id: other.id)

    migrate!

    expect(linked_seat_ids(order)).to be_empty
    SeatAssignment.where(id: old_seat_ids).each do |sa|
      expect(sa).to have_attributes(status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil,
                                    ticket_class_id: nil)
    end
    expect(order.reload.status).to eq(Order::PROCESSED)
  end

  it 'is a no-op on rerun' do
    order, = stale_released(Order::UNCLAIMED)
    migrate!
    snapshot = lambda do
      [LineItem.order(:id).pluck(:id, :seat_assignment_id, :updated_at),
       SeatAssignment.order(:id).pluck(:id, :status, :order_uuid, :updated_at)]
    end
    before = snapshot.call
    output = capture_stdout { described_class.new.up }
    expect(snapshot.call).to eq(before)
    expect(output).to include('cleared seat links: none', 'released held seats: none', '0 order(s) for manual review',
                              'released seats held on another performance: none')
    expect(linked_seat_ids(order)).to be_empty
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
