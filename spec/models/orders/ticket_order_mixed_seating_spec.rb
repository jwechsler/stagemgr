require 'rails_helper'

# Reserved-seating orders may now contain ticket classes that do NOT hold a
# seat (holds_seats == false): hearing-assist devices, meal bundles, or a small
# GA section inside a reserved house. These "non-seat" tickets are plain
# TicketLineItems with seat_assignment_id NULL. They consume no house capacity
# (Performance#seats_held filters holds_seats = true) and are capped per class
# by TicketClassAllocation#ticket_limit.
RSpec.describe 'reserved-seating orders with non-seat-holding tickets' do
  let(:production) { FactoryBot.create(:production_with_reserved_seating) }
  let(:performance) do
    FactoryBot.create(:reserved_seating, production: production,
                                         performance_date: Date.today + 1.day,
                                         performance_time: Time.parse('19:00'))
  end

  before { SeatAssignment.available_seat_assignments(performance) }

  def allocated_class(holds_seats:, ticket_limit: nil, **attrs)
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: holds_seats, **attrs)
    tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
    tca.available = true
    tca.ticket_limit = ticket_limit
    tca.save!
    performance.ticket_class_allocations.reload
    tc
  end

  def new_order(status: Order::HOLD)
    TicketOrder.new(
      status: status,
      performance: performance,
      address: FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type)
    )
  end

  # Per-seat shape: 1 TLI per seat with seat_assignment_id set.
  def add_seat_ticket(order, ticket_class)
    sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
    sa.update!(order_uuid: order.uuid, ticket_class_id: ticket_class.id,
               status: SeatAssignment::ASSIGNED)
    order.seats << sa
    order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                ticket_class: ticket_class,
                                                ticket_count: 1,
                                                seat_assignment_id: sa.id,
                                                order: order)
    sa
  end

  def add_non_seat_ticket(order, ticket_class, count: 1)
    tli = FactoryBot.build(:ticket_line_item,
                           ticket_class: ticket_class,
                           ticket_count: count,
                           order: order)
    order.ticket_line_items << tli
    tli
  end

  describe 'validity and seat counting' do
    it 'accepts a mixed order (seats match only the seat-holding tickets)' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      add_seat_ticket(order, seat_class)
      add_seat_ticket(order, seat_class)
      add_non_seat_ticket(order, addon)

      expect(order).to be_valid
      expect(order.number_of_seats).to eq(2)
      expect(order.number_of_tickets).to eq(3)
    end

    # Model-level capability used by the box office; the public flow
    # additionally requires a seated ticket (OrdersHelper#validate_web_order).
    it 'accepts an order containing ONLY non-seat tickets in a reserved house' do
      addon = allocated_class(holds_seats: false)
      order = new_order
      add_non_seat_ticket(order, addon)

      expect(order).to be_valid
      expect(order.number_of_seats).to eq(0)
    end

    it 'still rejects a seat-holding ticket without a seat' do
      seat_class = allocated_class(holds_seats: true)
      order = new_order
      order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                  ticket_class: seat_class,
                                                  ticket_count: 1, order: order)

      expect(order).not_to be_valid
      expect(order.errors[:seats].join).to include('do not match tickets')
    end
  end

  describe 'house capacity' do
    it 'does not count non-seat tickets against seats held' do
      addon = allocated_class(holds_seats: false)
      order = new_order
      add_non_seat_ticket(order, addon, count: 3)
      order.save!

      expect(performance.seats_held).to eq(0)
    end
  end

  describe 'per-class inventory (ticket_limit)' do
    it 'rejects an order exceeding the allocation limit across qty-1 line items' do
      addon = allocated_class(holds_seats: false, ticket_limit: 2)
      order = new_order
      add_non_seat_ticket(order, addon)
      add_non_seat_ticket(order, addon)
      add_non_seat_ticket(order, addon)

      expect(order).not_to be_valid
      expect(order.errors[:base].join).to match(/tickets remaining|tickets left/)
    end

    it 'accepts an order within the allocation limit' do
      addon = allocated_class(holds_seats: false, ticket_limit: 2)
      order = new_order
      add_non_seat_ticket(order, addon)
      add_non_seat_ticket(order, addon)

      expect(order).to be_valid
    end
  end

  describe '#flatten_ticket_line_items' do
    it 'yields seat: nil for non-seat tickets without warning' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      sa = add_seat_ticket(order, seat_class)
      add_non_seat_ticket(order, addon)
      order.save!

      expect(Rails.logger).not_to receive(:warn).with(/Ticket without matching seat assignment/)
      tickets = order.flatten_ticket_line_items

      expect(tickets.size).to eq(2)
      seat_ticket = tickets.find { |t| t[:ticket_class_id] == seat_class.id }
      addon_ticket = tickets.find { |t| t[:ticket_class_id] == addon.id }
      expect(seat_ticket[:seat].id).to eq(sa.id)
      expect(addon_ticket[:seat]).to be_nil
    end
  end

  describe '#build_tktprint_payload' do
    it 'assigns seat locations by seat_assignment_id even with a non-seat ticket interleaved' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      sa1 = add_seat_ticket(order, seat_class)
      add_non_seat_ticket(order, addon)
      sa2 = add_seat_ticket(order, seat_class)
      order.save!

      payload = order.send(:build_tktprint_payload, 'BATCH-1', 1)
      tickets = payload[:tickets_attributes]

      expect(tickets.size).to eq(3)
      seats_printed = tickets.select { |t| t[:ticket_class] == seat_class.class_code }.pluck(:seat)
      expect(seats_printed).to match_array([sa1.seat.location, sa2.seat.location])
      addon_ticket = tickets.find { |t| t[:ticket_class] == addon.class_code }
      expect(addon_ticket[:seat]).to eq('')
    end

    it 'still resolves seats for legacy aggregated line items by ticket class' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      # legacy shape: one TLI count=2, seats matched by ticket_class_id
      order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                  ticket_class: seat_class,
                                                  ticket_count: 2, order: order)
      locations = 2.times.map do
        sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
        sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id,
                   status: SeatAssignment::ASSIGNED)
        order.seats << sa
        sa.seat.location
      end
      add_non_seat_ticket(order, addon)
      order.save!

      payload = order.send(:build_tktprint_payload, 'BATCH-1', 1)
      tickets = payload[:tickets_attributes]
      seats_printed = tickets.select { |t| t[:ticket_class] == seat_class.class_code }.pluck(:seat)
      expect(seats_printed).to match_array(locations)
      expect(tickets.find { |t| t[:ticket_class] == addon.class_code }[:seat]).to eq('')
    end
  end

  describe 'nested-attributes key scheme' do
    # The reserved-seating form keys seat rows by seat_assignment_id and
    # non-seat rows by 1e9/2e9-offset integers. Strong params only keeps
    # integer-shaped keys, so this pins that big keys survive the real
    # public/admin permit list end-to-end.
    let(:helper_host) do
      Class.new do
        include OrdersHelper
        include TicketOrdersHelper
      end.new
    end

    it 'creates a non-seat line item from a 2e9-offset key' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      add_seat_ticket(order, seat_class)
      order.save!

      params = ActionController::Parameters.new(
        ticket_order: {
          ticket_line_items_attributes: {
            '2000000001' => { 'ticket_class_id' => addon.id.to_s, 'ticket_count' => '1' }
          }
        }
      )
      permitted = params.require(:ticket_order).permit(*helper_host.ticket_order_common_params)
      order.update!(permitted)

      expect(order.reload.ticket_line_items.map(&:ticket_class_id)).to include(addon.id)
    end

    it 'destroys a persisted non-seat line item via _destroy' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = new_order
      add_seat_ticket(order, seat_class)
      add_non_seat_ticket(order, addon)
      order.save!
      tli_id = order.ticket_line_items.find { |t| t.ticket_class_id == addon.id }.id

      params = ActionController::Parameters.new(
        ticket_order: {
          ticket_line_items_attributes: {
            (1_000_000_000 + tli_id).to_s => { 'id' => tli_id.to_s, '_destroy' => '1' }
          }
        }
      )
      permitted = params.require(:ticket_order).permit(*helper_host.ticket_order_common_params)
      order.update!(permitted)

      expect(order.reload.ticket_line_items.map(&:ticket_class_id)).not_to include(addon.id)
    end
  end

  describe 'exchange' do
    it 'exchanges a mixed order, retaining the non-seat ticket on the new order' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)

      original = new_order(status: Order::NEW)
      add_seat_ticket(original, seat_class)
      add_non_seat_ticket(original, addon)
      original.save!
      original.payments << FactoryBot.create(:cash_payment, order: original,
                                                            number_of_tickets: 2,
                                                            amount: original.total_due)
      original.status = Order::PROCESSED
      original.save!

      exchange = new_order(status: Order::NEW)
      add_seat_ticket(exchange, seat_class)
      add_non_seat_ticket(exchange, addon)

      exchange.exchange_and_process_from! original

      expect(exchange.status).to eq(Order::PROCESSED)
      expect(original.reload.status).to eq(Order::EXCHANGED)
      addon_tlis = exchange.ticket_line_items.select { |t| t.ticket_class_id == addon.id }
      expect(addon_tlis.map(&:ticket_count).sum).to eq(1)
      expect(exchange.number_of_seats).to eq(1)
    end
  end
end
