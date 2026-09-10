require 'rails_helper'

# Cancelling an order destroys the row (Order#cancel!), so the scheduled
# CalculateHouseCountsJob sweep -- which finds performances through recently
# updated orders -- can never see it. The order itself must queue a targeted
# recalculation for its performance whenever its seat footprint changes.
RSpec.describe TicketOrder, 'house count refresh', type: :model do
  let!(:performance) { FactoryBot.create(:general_admission) }
  let!(:order) do
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, status: Order::HOLD)
  end

  before { allow(Resque).to receive(:enqueue) }

  it 'queues a recalculation for the performance when a held order is cancelled' do
    expect(Resque).to receive(:enqueue).with(CalculateHouseCountsJob, performance.id)
    expect(order.cancel!).to be true
  end

  it 'queues a recalculation when a processed order is refunded' do
    order.update!(status: Order::PROCESSED)
    expect(Resque).to receive(:enqueue).with(CalculateHouseCountsJob, performance.id)
    order.update!(status: Order::REFUNDED)
  end

  it 'queues a recalculation when an order status changes' do
    expect(Resque).to receive(:enqueue).with(CalculateHouseCountsJob, performance.id)
    order.update!(status: Order::UNCLAIMED)
  end

  it 'does not queue a recalculation for edits that leave the status alone' do
    expect(Resque).not_to receive(:enqueue).with(CalculateHouseCountsJob, anything)
    order.update!(notes: 'no seat change')
  end
end
