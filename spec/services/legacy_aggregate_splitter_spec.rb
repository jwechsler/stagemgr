require 'rails_helper'

RSpec.describe LegacyAggregateSplitter do
  let(:production) { FactoryBot.create(:production_with_reserved_seating) }
  let(:performance) do
    FactoryBot.create(:reserved_seating, production: production,
                                         performance_date: Date.current + 1.day,
                                         performance_time: Time.zone.parse('19:00'))
  end
  let(:ticket_type) { 'Fixed' }
  let(:seat_class) do
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: true, ticket_type: ticket_type)
    tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
    tca.available = true
    tca.save!
    performance.ticket_class_allocations.reload
    tc
  end

  before { SeatAssignment.available_seat_assignments(performance) }

  # Saved in the legacy shape: one aggregate of ticket_count, seat_count seats.
  def legacy_order(ticket_count: 3, seat_count: ticket_count)
    order = TicketOrder.new(status: Order::PROCESSED, performance: performance,
                            address: FactoryBot.create(:address),
                            payment_type: FactoryBot.create(:cash_payment_type))
    order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: seat_class,
                                                                   ticket_count: ticket_count, order: order)
    seat_count.times do
      sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
      sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id, status: SeatAssignment::ASSIGNED)
      order.seats << sa
    end
    order.save!(validate: false)
    TicketOrder.find(order.id)
  end

  def line_item_shape(order)
    TicketLineItem.where(order_id: order.id).order(:id).pluck(:ticket_count, :seat_assignment_id)
  end

  it 'selects upcoming reserved-seating orders that still hold an aggregate' do
    order = legacy_order

    expect(described_class.candidate_orders).to include(order)
  end

  it 'splits an aggregate into one line item per seat' do
    order = legacy_order

    result = described_class.new(order, dry_run: false).call

    expect(result.status).to eq(LegacyAggregateSplitter::SPLIT)
    expect(result.seats_split).to eq(3)
    order = TicketOrder.find(order.id)
    expect(order.ticket_line_items.map(&:ticket_count)).to eq([1, 1, 1])
    expect(order.ticket_line_items.map(&:seat_assignment_id)).to match_array(order.seats.map(&:id))
    expect(order.number_of_seats).to eq(3)
    expect(described_class.candidate_orders).not_to include(order)
  end

  context 'with a donation class' do
    let(:ticket_type) { TicketClass::DONATION }

    it 'keeps the price override of a seat' do
      order = legacy_order
      priced = order.seats.min_by(&:id)
      priced.update_columns(price_override: 7.5)

      described_class.new(order, dry_run: false).call

      expect(TicketLineItem.find_by(seat_assignment_id: priced.id).price_override).to eq(7.5)
    end
  end

  it 'changes nothing in DRY_RUN mode' do
    order = legacy_order
    before = line_item_shape(order)

    result = described_class.new(order, dry_run: true).call

    expect(result.status).to eq(LegacyAggregateSplitter::WOULD_SPLIT)
    expect(result.seats_split).to eq(3)
    expect(line_item_shape(order)).to eq(before)
  end

  it 'skips an order whose seats and ticket count disagree' do
    order = legacy_order(ticket_count: 3, seat_count: 2)
    before = line_item_shape(order)

    result = described_class.new(order, dry_run: false).call

    expect(result.status).to eq(LegacyAggregateSplitter::SKIPPED)
    expect(result.message).to include('ticket_count 3', '2 unlinked seat(s)')
    expect(line_item_shape(order)).to eq(before)
  end
end
