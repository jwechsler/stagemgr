require 'rails_helper'

# #ticket-line-item-merge is the server→JS bridge that lets the order form
# rebuild the unified ticket list on page load. Reserved orders emit one
# .reserved-seat-entry per assigned seat, plus one .non-seat-ticket-entry per
# non-seat-holding TicketLineItem (holds_seats == false, no SeatAssignment).
# Legacy aggregated seat-holding TLIs (nil seat_assignment_id but a
# holds_seats class) must NOT emit non-seat entries — their seats already
# represent them.
RSpec.describe 'admin/ticket_orders/_ticket_line_item_table', type: :view do
  let(:production) { FactoryBot.create(:production_with_reserved_seating) }
  let(:performance) do
    FactoryBot.create(:reserved_seating, production: production,
                                         performance_date: Date.today + 1.day,
                                         performance_time: Time.parse('19:00'))
  end

  before { SeatAssignment.available_seat_assignments(performance) }

  def allocated_class(holds_seats:, class_name:)
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: holds_seats,
                                          class_name: class_name)
    tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
    tca.available = true
    tca.save!
    tc
  end

  def order_with(seat_tickets: 0, non_seat_tickets: 0, legacy_aggregated: false)
    seat_class = allocated_class(holds_seats: true, class_name: 'Main Floor')
    addon_class = allocated_class(holds_seats: false, class_name: 'Hearing Assist')
    order = TicketOrder.new(
      status: Order::HOLD,
      performance: performance,
      address: FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type)
    )
    if legacy_aggregated
      order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: seat_class,
                                                                     ticket_count: seat_tickets, order: order)
      seat_tickets.times do
        sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
        sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id, status: SeatAssignment::ASSIGNED)
        order.seats << sa
      end
    else
      seat_tickets.times do
        sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
        sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id, status: SeatAssignment::ASSIGNED)
        order.seats << sa
        order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: seat_class,
                                                                       ticket_count: 1,
                                                                       seat_assignment_id: sa.id, order: order)
      end
    end
    non_seat_tickets.times do
      order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: addon_class,
                                                                     ticket_count: 1, order: order)
    end
    order.save!
    order
  end

  it 'emits a non-seat-ticket-entry for each persisted non-seat line item' do
    order = order_with(seat_tickets: 1, non_seat_tickets: 1)
    render partial: 'admin/ticket_orders/ticket_line_item_table', locals: { ticket_order: order }

    expect(rendered).to include('reserved-seat-entry')
    expect(rendered).to include('non-seat-ticket-entry')
    expect(rendered).to include('Hearing Assist')
  end

  it 'does not emit non-seat entries for legacy aggregated seat-holding line items' do
    order = order_with(seat_tickets: 2, non_seat_tickets: 0, legacy_aggregated: true)
    render partial: 'admin/ticket_orders/ticket_line_item_table', locals: { ticket_order: order }

    expect(rendered).to include('reserved-seat-entry')
    expect(rendered).not_to include('non-seat-ticket-entry')
  end
end
