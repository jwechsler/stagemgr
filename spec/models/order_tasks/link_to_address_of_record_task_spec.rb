require 'rails_helper'

RSpec.describe LinkToAddressOfRecordTask, type: :model do
  include_context 'auto-fulfilling print service'

  def order_with_duplicate_address
    dup_attrs = { full_name: 'Pat Patron', first_name: 'Pat', last_name: 'Patron',
                  email: 'pat.patron@example.com' }
    keeper = FactoryBot.create(:address, **dup_attrs)
    buyer = FactoryBot.create(:address, **dup_attrs)
    order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash, address: buyer)
    [order, keeper, buyer]
  end

  def run_task_for(order)
    task = LinkToAddressOfRecordTask.create!(order: order, execute_at: 1.minute.ago)
    task.run!
    task.reload
  end

  it 'merges the duplicate address for a fulfilled order and completes' do
    order, keeper, buyer = order_with_duplicate_address
    order.transition_to!(Order::PROCESSED)

    task = run_task_for(order)

    expect(task.status).to eq(OrderTask::COMPLETED)
    expect(order.reload.address_id).to eq(keeper.id)
    expect(Address.exists?(buyer.id)).to be(false)
  end

  it 'still merges for a refunded order' do
    order, keeper, buyer = order_with_duplicate_address
    order.transition_to!(Order::PROCESSED)
    order.update!(status: Order::REFUNDED)

    task = run_task_for(order)

    expect(task.status).to eq(OrderTask::COMPLETED)
    expect(order.reload.address_id).to eq(keeper.id)
    expect(Address.exists?(buyer.id)).to be(false)
  end

  it 'fails with a recorded backtrace and persisted attempt count when the merge raises' do
    order, = order_with_duplicate_address
    order.transition_to!(Order::PROCESSED)
    allow_any_instance_of(Order).to receive(:link_to_address_of_record)
      .and_raise(StandardError, 'merge exploded')

    task = run_task_for(order)

    expect(task.status).to eq(OrderTask::FAILED)
    expect(task.attempts).to eq(1)
    expect(task.result).to include('merge exploded')
  end

  it 'completes when a concurrent merge already consumed the duplicate' do
    order, = order_with_duplicate_address
    order.transition_to!(Order::PROCESSED)
    allow_any_instance_of(Order).to receive(:link_to_address_of_record)
      .and_raise(ActiveRecord::RecordNotFound)

    task = run_task_for(order)

    expect(task.status).to eq(OrderTask::COMPLETED)
  end

  it 'returns to the queue while the order is unprocessed' do
    order, _keeper, buyer = order_with_duplicate_address
    order.update_columns(status: Order::HOLD) # the paid_with_cash trait processes the order

    task = run_task_for(order)

    expect(task.status).to eq(OrderTask::FAILED) # retried on later polls
    expect(Address.exists?(buyer.id)).to be(true)
  end

  describe 'refund task cancellation' do
    it 'cancels a pending MyEmmaTask but leaves the address-of-record task pending' do
      order, = order_with_duplicate_address
      order.transition_to!(Order::PROCESSED)
      emma = MyEmmaTask.create!(order: order, execute_at: 5.minutes.from_now)
      link = order.tasks.reload.find { |t| t.is_a?(LinkToAddressOfRecordTask) } ||
             LinkToAddressOfRecordTask.create!(order: order, execute_at: 5.minutes.from_now)

      order.update!(status: Order::REFUNDED)

      expect(emma.reload.status).to eq(OrderTask::CANCELLED)
      expect(link.reload.status).to eq(OrderTask::UNTRIED)
    end
  end
end
