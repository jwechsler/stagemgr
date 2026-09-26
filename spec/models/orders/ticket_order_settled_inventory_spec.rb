require 'rails_helper'

# Ticket limits and capacity are checked while an order is being placed. Once
# it is settled the sale is made, and a later inventory change must not stop
# the order being saved again -- e.g. PrintBatchJob marking it FULFILLED after
# its tickets have printed.
RSpec.describe TicketOrder, 'inventory checks after the order is settled' do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }
  let(:line_item) { order.ticket_line_items.first }
  let(:allocation) do
    TicketClassAllocation.find_by!(performance_id: order.performance_id, ticket_class_id: line_item.ticket_class_id)
  end

  def unplaced_copy_of(order, status:)
    copy = TicketOrder.new(status: status, performance: order.performance, address: order.address,
                           payment_type: order.payment_type)
    copy.ticket_line_items << TicketLineItem.new(ticket_class: line_item.ticket_class, ticket_count: 2)
    copy
  end

  context 'when the ticket limit is lowered below what was sold' do
    before { allocation.update!(ticket_limit: 1) }

    it 'still saves a processed order, e.g. to mark it fulfilled after printing' do
      order.reload.status = Order::FULFILLED

      expect(order).to be_valid
      expect { order.save! }.not_to raise_error
    end

    it 'still rejects an order that is being placed' do
      pending_order = unplaced_copy_of(order, status: Order::PROCESSING)

      expect(pending_order).not_to be_valid
      expect(pending_order.errors[:base].join).to match(/tickets left|tickets remaining/)
    end
  end

  context 'when capacity is reduced below the seats already sold' do
    before do
      order # sold while there was room
      allow_any_instance_of(Performance).to receive(:number_of_seats_left).and_return(0)
    end

    it 'still saves a settled order' do
      order.reload.status = Order::FULFILLED

      expect(order).to be_valid
    end

    it 'still rejects an order that is being placed' do
      pending_order = unplaced_copy_of(order, status: Order::NEW)

      expect(pending_order).not_to be_valid
      expect(pending_order.errors[:base].join).to match(/reservations? remaining/)
    end
  end

  it 'still requires an allocation for every ticket class, settled or not' do
    allocation.delete
    order.reload.status = Order::FULFILLED

    expect(order).not_to be_valid
    expect(order.errors[:base].join).to match(/Missing allocation/)
  end
end
