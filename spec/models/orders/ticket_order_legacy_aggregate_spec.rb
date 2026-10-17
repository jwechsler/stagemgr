require 'rails_helper'

# LEGACY: reserved-seating orders placed before per-seat line items carry one
# aggregated TicketLineItem per class (seat_assignment_id NULL). The admin
# order form posts every unlinked seat as a NEW per-seat line item; the
# aggregate must give those tickets up rather than be counted twice.
RSpec.describe 'TicketOrder legacy aggregated line items' do
  let(:production) { FactoryBot.create(:production_with_reserved_seating) }
  let(:performance) do
    FactoryBot.create(:reserved_seating, production: production,
                                         performance_date: Date.current + 1.day,
                                         performance_time: Time.zone.parse('19:00'))
  end
  let(:seat_class) { allocated_class(holds_seats: true) }

  before { SeatAssignment.available_seat_assignments(performance) }

  def allocated_class(holds_seats:)
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: holds_seats)
    tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
    tca.available = true
    tca.save!
    performance.ticket_class_allocations.reload
    tc
  end

  def new_order
    TicketOrder.new(status: Order::HOLD, performance: performance,
                    address: FactoryBot.create(:address),
                    payment_type: FactoryBot.create(:cash_payment_type))
  end

  def hold_seat(order, ticket_class)
    sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
    sa.update!(order_uuid: order.uuid, ticket_class_id: ticket_class.id, status: SeatAssignment::ASSIGNED)
    order.seats << sa
    sa
  end

  def add_line_item(order, ticket_class, count:, seat: nil)
    order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: ticket_class, ticket_count: count,
                                                                   seat_assignment_id: seat&.id, order: order)
  end

  def legacy_order(seat_count: 3)
    order = new_order
    add_line_item(order, seat_class, count: seat_count)
    seat_count.times { hold_seat(order, seat_class) }
    order.save!
    TicketOrder.find(order.id)
  end

  # Shaped like build_reserved_seat_row in seat_assignment.js: one group per
  # seat, keyed by the seat id, with no [id] for an unlinked seat.
  def form_attributes(order)
    order.seats.to_h do |sa|
      [sa.id.to_s, { ticket_class_id: sa.ticket_class_id.to_s, ticket_count: '1', seat_assignment_id: sa.id.to_s }]
    end
  end

  def line_item_shape(order)
    TicketLineItem.where(order_id: order.id).order(:id).pluck(:ticket_class_id, :ticket_count, :seat_assignment_id)
  end

  it 'replaces the aggregate with the per-seat items the admin form posts' do
    order = legacy_order
    aggregate_id = order.ticket_line_items.first.id

    order.assign_attributes(ticket_line_items_attributes: form_attributes(order))

    expect(order.save).to be(true), order.errors.full_messages.join('; ')
    order.reload
    expect(order.number_of_seats).to eq(3)
    expect(TicketLineItem.exists?(aggregate_id)).to be(false)
    expect(order.ticket_line_items.map(&:seat_assignment_id)).to match_array(order.seats.map(&:id))
    expect(order.ticket_line_items.map(&:ticket_count)).to eq([1, 1, 1])
  end

  it 'keeps the rest of an aggregate when only some seats are posted as new items' do
    order = legacy_order
    first_seat = order.seats.min_by(&:id)
    order.assign_attributes(ticket_line_items_attributes: form_attributes(order).slice(first_seat.id.to_s))
    order.valid?

    aggregate = order.ticket_line_items.detect { |tli| tli.seat_assignment_id.nil? }
    expect(aggregate.ticket_count).to eq(2)
    expect(aggregate).not_to be_marked_for_destruction
    expect(order.number_of_seats).to eq(3)
  end

  it 'leaves a saved mix of aggregate and split-off per-seat item alone' do
    order = new_order
    add_line_item(order, seat_class, count: 2)
    hold_seat(order, seat_class)
    hold_seat(order, seat_class)
    add_line_item(order, seat_class, count: 1, seat: hold_seat(order, seat_class))
    order.save!
    order = TicketOrder.find(order.id)
    before = line_item_shape(order)

    expect(order.save).to be(true), order.errors.full_messages.join('; ')
    expect(line_item_shape(order)).to eq(before)
  end

  it 'leaves an order already in the per-seat shape unchanged' do
    order = new_order
    3.times { add_line_item(order, seat_class, count: 1, seat: hold_seat(order, seat_class)) }
    order.save!
    order = TicketOrder.find(order.id)
    before = line_item_shape(order)
    attributes = order.ticket_line_items.to_h do |tli|
      [tli.seat_assignment_id.to_s, { id: tli.id.to_s, ticket_class_id: tli.ticket_class_id.to_s,
                                      ticket_count: '1', seat_assignment_id: tli.seat_assignment_id.to_s }]
    end

    order.assign_attributes(ticket_line_items_attributes: attributes)

    expect(order.save).to be(true), order.errors.full_messages.join('; ')
    expect(line_item_shape(order)).to eq(before)
  end

  describe 'a form opened before the order was split' do
    def per_seat_order(ticket_class)
      order = new_order
      3.times { add_line_item(order, ticket_class, count: 1, seat: hold_seat(order, ticket_class)) }
      order.save!
      TicketOrder.find(order.id)
    end

    it 'drops new items posted for seats that already have a line item' do
      order = per_seat_order(seat_class)
      before = line_item_shape(order)
      before_ids = TicketLineItem.where(order_id: order.id).pluck(:id)

      order.assign_attributes(ticket_line_items_attributes: form_attributes(order))

      expect(order).to be_valid, order.errors.full_messages.join('; ')
      expect(order.number_of_seats).to eq(3)
      expect(order.save).to be(true)
      expect(TicketLineItem.where(order_id: order.id).pluck(:id)).to match_array(before_ids)
      expect(line_item_shape(order)).to eq(before)
      expect(order.reload.number_of_seats).to eq(3)
    end

    it 'moves a posted price override onto the existing line item' do
      donation_class = FactoryBot.create(:ticket_class, production: production, ticket_type: TicketClass::DONATION)
      performance.ticket_class_allocations.create!(ticket_class: donation_class, available: true)
      performance.ticket_class_allocations.reload
      order = per_seat_order(donation_class)
      seat = order.seats.min_by(&:id)
      attributes = form_attributes(order)
      attributes[seat.id.to_s][:price_override] = '12.5'

      order.assign_attributes(ticket_line_items_attributes: attributes)

      expect(order.save).to be(true), order.errors.full_messages.join('; ')
      expect(TicketLineItem.where(order_id: order.id).count).to eq(3)
      expect(TicketLineItem.find_by(seat_assignment_id: seat.id).price_override).to eq(12.5)
    end
  end

  it 'does not touch non-seat line items' do
    addon = allocated_class(holds_seats: false)
    order = new_order
    add_line_item(order, seat_class, count: 2)
    2.times { hold_seat(order, seat_class) }
    add_line_item(order, addon, count: 2)
    order.save!
    order = TicketOrder.find(order.id)
    addon_item = order.ticket_line_items.detect { |tli| tli.ticket_class_id == addon.id }

    order.assign_attributes(ticket_line_items_attributes: form_attributes(order))

    expect(order.save).to be(true), order.errors.full_messages.join('; ')
    expect(addon_item.reload.ticket_count).to eq(2)
    expect(addon_item.seat_assignment_id).to be_nil
    expect(order.reload.number_of_seats).to eq(2)
  end
end
