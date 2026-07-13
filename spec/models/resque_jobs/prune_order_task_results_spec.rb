require 'rails_helper'

RSpec.describe PruneOrderTaskResults do
  let(:order) { FactoryBot.create(:ticket_order) }

  def create_task(result:, age:)
    task = OutreachTask.create!(order: order, status: OrderTask::FAILED, result: result)
    task.update_column(:updated_at, age.ago)
    task
  end

  before { allow(described_class).to receive(:sleep) }

  it 'clears result on tasks older than the retention window' do
    stale = create_task(result: "boom\nbacktrace", age: 7.months)

    expect(described_class.perform).to eq(1)

    expect(stale.reload.result).to be_nil
  end

  it 'preserves result on tasks newer than the retention window' do
    fresh = create_task(result: "boom\nbacktrace", age: 1.month)

    expect(described_class.perform).to eq(0)

    expect(fresh.reload.result).to eq("boom\nbacktrace")
  end

  it 'ignores old tasks whose result is already empty' do
    cleared = create_task(result: nil, age: 7.months)

    expect(described_class.perform).to eq(0)

    expect(cleared.reload.updated_at).to be < 6.months.ago
  end

  it 'works through multiple batches until no stale results remain' do
    stub_const('PruneOrderTaskResults::BATCH_SIZE', 2)
    tasks = Array.new(5) { create_task(result: 'trace', age: 8.months) }

    expect(described_class.perform).to eq(5)

    tasks.each { |task| expect(task.reload.result).to be_nil }
  end
end
