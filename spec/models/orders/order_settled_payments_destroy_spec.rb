require 'rails_helper'

# Order#check_for_settled_payments must actually halt a destroy: a returned
# false is ignored by Rails 5+, so it throws :abort.
RSpec.describe Order, 'destroying an order with settled payments' do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

  it 'keeps an order holding a settled payment' do
    expect(order.destroy).to be(false)

    expect(Order.exists?(order.id)).to be(true)
    expect(order.payments.reload).not_to be_empty
    expect(order.ticket_line_items.reload).not_to be_empty
    expect(order.errors.full_messages).to include('Order Cannot destroy orders with settled payments')
  end

  it 'raises from destroy!' do
    expect { order.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(Order.exists?(order.id)).to be(true)
  end

  it 'still deletes an order whose payments can all be cancelled' do
    order.payments.each { |payment| payment.update_columns(amount: 0) }

    expect(order.reload.destroy).to be_truthy
    expect(Order.exists?(order.id)).to be(false)
  end

  it 'still deletes an order with no payments' do
    unpaid = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)

    expect(unpaid.destroy).to be_truthy
    expect(Order.exists?(unpaid.id)).to be(false)
  end
end
