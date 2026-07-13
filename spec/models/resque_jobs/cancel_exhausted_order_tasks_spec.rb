require 'rails_helper'

RSpec.describe CancelExhaustedOrderTasks do
  let(:order) { FactoryBot.create(:ticket_order) }

  def create_task(status:, attempts:)
    OutreachTask.create!(order: order, status: status, attempts: attempts, execute_at: 1.day.ago)
  end

  before { allow(described_class).to receive(:sleep) }

  it 'cancels Failed tasks that have exhausted their attempts' do
    exhausted = create_task(status: OrderTask::FAILED, attempts: OrderTask::MAX_ATTEMPTS)

    expect(described_class.perform).to eq(1)

    expect(exhausted.reload.status).to eq(OrderTask::CANCELLED)
  end

  it 'preserves Failed tasks that still have attempts left' do
    retryable = create_task(status: OrderTask::FAILED, attempts: OrderTask::MAX_ATTEMPTS - 1)

    expect(described_class.perform).to eq(0)

    expect(retryable.reload.status).to eq(OrderTask::FAILED)
  end

  it 'preserves Untried and Completed tasks regardless of attempts' do
    untried = create_task(status: OrderTask::UNTRIED, attempts: 0)
    completed = create_task(status: OrderTask::COMPLETED, attempts: OrderTask::MAX_ATTEMPTS)

    described_class.perform

    expect(untried.reload.status).to eq(OrderTask::UNTRIED)
    expect(completed.reload.status).to eq(OrderTask::COMPLETED)
  end

  it 'works through multiple batches until no exhausted tasks remain' do
    stub_const('CancelExhaustedOrderTasks::BATCH_SIZE', 2)
    tasks = Array.new(5) { create_task(status: OrderTask::FAILED, attempts: OrderTask::MAX_ATTEMPTS + 3) }

    expect(described_class.perform).to eq(5)

    tasks.each { |task| expect(task.reload.status).to eq(OrderTask::CANCELLED) }
  end
end
