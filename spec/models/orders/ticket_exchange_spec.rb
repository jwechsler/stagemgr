require 'rails_helper'

RSpec.describe "an exchanged ticket order" do
  it "should have an offset payment" do
    original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    exchange_order = FactoryBot.create(:ticket_order)
    expect(original_order.payments.size).to eq(1)
    ticket_line_item = original_order.ticket_line_items.first.dup
    ticket_line_item.ticket_class = exchange_order.performance.ticket_class_allocations.first.ticket_class
    exchange_order.ticket_line_items << ticket_line_item
    exchange_order.exchange_and_process_from! original_order
    expect(exchange_order.payments.size).to eq(1)
    expect(original_order.payments.size).to eq(2)
    expect(original_order.status).to eq(Order::EXCHANGED)
    expect(original_order.total).to eq(0.0)
    expect(exchange_order.total(:include_override_payments)).to eq(12.0)
    expect(exchange_order.total).to eq(12.0)
    expect(exchange_order.exchange_source_id).to eq(original_order.id)
  end

end
