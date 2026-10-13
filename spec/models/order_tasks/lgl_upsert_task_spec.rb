# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglUpsertTask, type: :model do
  include_context 'auto-fulfilling print service'

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Resque).to receive(:enqueue)
  end

  def processed_donation
    order = FactoryBot.create(:donation_order_for_one_thousand_dollars)
    order.update!(status: Order::PROCESSED)
    order
  end

  def lgl_tasks(order)
    order.tasks.reload.grep(described_class)
  end

  def run(task)
    task.update!(execute_at: 1.minute.ago)
    task.run!
    task.reload
  end

  def complete_link_task(order)
    order.tasks.where(type: 'LinkToAddressOfRecordTask').find_each { |t| t.update!(status: OrderTask::COMPLETED) }
  end

  describe 'creation' do
    it 'is created ten minutes out when a donation order reaches PROCESSED' do
      freeze_time do
        order = processed_donation
        expect(lgl_tasks(order).map(&:execute_at)).to eq([Time.now + LglUpsertTask::LGL_DELAY])
      end
    end

    it 'is not created for a ticket order reaching PROCESSED' do
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash)
      order.transition_to!(Order::PROCESSED)
      expect(lgl_tasks(order)).to be_empty
    end

    it 'is not created when LGL is disabled' do
      allow(Lgl).to receive(:enabled?).and_return(false)
      expect(lgl_tasks(processed_donation)).to be_empty
    end

    it 'is not created when the order asks for no tasks' do
      order = FactoryBot.create(:donation_order_for_one_thousand_dollars)
      order.do_not_create_tasks = true
      order.update!(status: Order::PROCESSED)
      expect(lgl_tasks(order)).to be_empty
    end
  end

  describe 'running' do
    it 'defers while the address-of-record link is still pending' do
      order = processed_donation
      task = run(lgl_tasks(order).first)

      expect(task.status).to eq(OrderTask::FAILED)
      expect(task).to be_uncompleted
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'defers while the order is unprocessed' do
      order = processed_donation
      complete_link_task(order)
      task = lgl_tasks(order).first
      order.update_column(:status, Order::NEW)

      expect(run(task).status).to eq(OrderTask::FAILED)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'enqueues a donation sync for the address the order points at when it runs' do
      order = processed_donation
      complete_link_task(order)
      task = lgl_tasks(order).first
      keeper = FactoryBot.create(:address)
      order.update_column(:address_id, keeper.id)

      expect(run(task).status).to eq(OrderTask::COMPLETED)
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, keeper.id, 'donation')
    end

    it 'completes without enqueuing for a placeholder address' do
      order = processed_donation
      complete_link_task(order)
      order.address.update_column(:placeholder, true)

      expect(run(lgl_tasks(order).first).status).to eq(OrderTask::COMPLETED)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'completes without enqueuing once LGL has been disabled' do
      order = processed_donation
      complete_link_task(order)
      allow(Lgl).to receive(:enabled?).and_return(false)

      expect(run(lgl_tasks(order).first).status).to eq(OrderTask::COMPLETED)
      expect(Resque).not_to have_received(:enqueue)
    end
  end
end
