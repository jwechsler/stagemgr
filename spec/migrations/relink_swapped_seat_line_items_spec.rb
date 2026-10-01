require 'rails_helper'
require Rails.root.join('db/migrate/20261001100000_relink_swapped_seat_line_items')

RSpec.describe RelinkSwappedSeatLineItems do
  def migrate!
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  def pass_class_for(order, code)
    FactoryBot.create(:ticket_class, production: order.performance.production, class_code: code,
                                     class_name: 'Pass Ticket', ticket_price: 0.00, web_visible: false,
                                     software_managed: true)
  end

  def add_pass_payment!(order, type = 'MembershipPayment')
    payment = type.constantize.new(order_id: order.id, amount: 0,
                                   payment_type: FactoryBot.create(:membership_payment_type))
    payment.membership = FactoryBot.create(:membership, address: order.address) if payment.is_a?(MembershipPayment)
    payment.save!(validate: false)
  end

  # The pre-fix redemption shape: the order still holds its Assigned seats
  # (picked as the priced class) but its line items are seatless pass tickets.
  def swapped_order(code: 'PASS', status: Order::PROCESSED)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    pass_class = pass_class_for(order, code)
    order.ticket_line_items.to_a.each(&:destroy)
    order.seats.each do |sa|
      sa.update_columns(status: SeatAssignment::ASSIGNED, order_id: order.id)
      order.ticket_line_items.create!(ticket_class: pass_class, ticket_count: 1)
    end
    order.update_columns(status: status)
    [order.reload, pass_class]
  end

  def tlis(order)
    TicketLineItem.where(order_id: order.id).order(:id)
  end

  it 'links a membership order and gives each seat the pass class' do
    order, pass_class = swapped_order
    add_pass_payment!(order)
    seats = order.seats.sort_by { |sa| [sa.seat.location, sa.id] }

    migrate!

    expect(tlis(order).map(&:seat_assignment_id)).to eq(seats.map(&:id))
    expect(SeatAssignment.where(id: seats.map(&:id)).pluck(:ticket_class_id).uniq).to eq([pass_class.id])
  end

  it 'links a flex pass order' do
    order, = swapped_order(code: 'FLEX')
    add_pass_payment!(order, 'FlexPassPayment')

    migrate!

    expect(tlis(order).map(&:seat_assignment_id)).to match_array(order.seats.map(&:id))
  end

  it 'links a special offer order' do
    order, = swapped_order(code: 'OFFER')
    SpecialOfferLineItem.new(order_id: order.id).save!(validate: false)

    migrate!

    expect(tlis(order).map(&:seat_assignment_id)).to match_array(order.seats.map(&:id))
  end

  it 'prints the repaired order with its seat locations' do
    order, = swapped_order
    add_pass_payment!(order)
    locations = order.seats.map { |sa| sa.seat.location }

    migrate!

    payload = TicketOrder.find(order.id).send(:build_tktprint_payload, 'batch', 1)
    expect(payload[:tickets_attributes].pluck(:seat)).to match_array(locations)
  end

  it 'pairs a seat still carrying a line item class with that line item first' do
    order, pass_class = swapped_order
    add_pass_payment!(order)
    other = pass_class_for(order, 'OTHER')
    second_tli = tlis(order).last
    second_tli.update_columns(ticket_class_id: other.id)
    # The seat that sorts first already carries the second line item's class.
    first_seat = order.seats.min_by { |sa| [sa.seat.location, sa.id] }
    first_seat.update_columns(ticket_class_id: other.id)

    migrate!

    expect(second_tli.reload.seat_assignment_id).to eq(first_seat.id)
    expect(tlis(order).first.seat_assignment.ticket_class_id).to eq(pass_class.id)
  end

  it 'skips an order whose seatless line items and free seats do not match' do
    order, = swapped_order
    add_pass_payment!(order)
    tlis(order).first.update_columns(seat_assignment_id: order.seats.first.id)
    order.ticket_line_items.create!(ticket_class: tlis(order).last.ticket_class, ticket_count: 1)

    expect { migrate! }.not_to(change { tlis(order).pluck(:seat_assignment_id) })
  end

  it 'skips an order with a seatless line item holding more than one ticket' do
    order, pass_class = swapped_order
    add_pass_payment!(order)
    tlis(order).delete_all
    order.ticket_line_items.create!(ticket_class: pass_class, ticket_count: 2)

    migrate!

    expect(tlis(order).pluck(:seat_assignment_id)).to eq([nil])
  end

  it 'leaves an order for a past performance untouched' do
    order, = swapped_order
    add_pass_payment!(order)
    order.performance.update_columns(performance_date: Date.current - 1)

    migrate!

    expect(tlis(order).pluck(:seat_assignment_id)).to all(be_nil)
  end

  it 'leaves a refunded order untouched' do
    order, = swapped_order(status: Order::REFUNDED)
    add_pass_payment!(order)

    migrate!

    expect(tlis(order).pluck(:seat_assignment_id)).to all(be_nil)
  end

  it 'leaves an aggregated, class-matching bulk-import order untouched' do
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    order.update_columns(status: Order::PROCESSED)
    seat_classes = order.seats.map(&:ticket_class_id)

    expect { migrate! }.not_to(change { tlis(order).pluck(:seat_assignment_id, :ticket_count) })
    expect(order.seats.reload.map(&:ticket_class_id)).to eq(seat_classes)
  end

  it 'finds nothing to do when run again' do
    order, = swapped_order
    add_pass_payment!(order)
    migrate!
    linked = tlis(order).pluck(:id, :seat_assignment_id)
    seat_rows = SeatAssignment.where(id: order.seats.map(&:id)).pluck(:id, :ticket_class_id, :updated_at)

    expect { described_class.new.up }.to output(/relinked 0 line items on 0 orders; skipped 0 orders/).to_stdout
    expect(tlis(order).pluck(:id, :seat_assignment_id)).to eq(linked)
    expect(SeatAssignment.where(id: order.seats.map(&:id)).pluck(:id, :ticket_class_id, :updated_at)).to eq(seat_rows)
  end
end
