require 'rails_helper'
require 'rake'

RSpec.describe 'outreach:backfill' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'outreach:backfill' }
  end

  after { ENV.delete('DRY_RUN') }

  def run_task
    Rake::Task['outreach:backfill'].execute
  end

  # simulates an order processed while task creation was disconnected
  def order_missing_tasks(status: Order::PROCESSED)
    performance = FactoryBot.create(:general_admission, performance_date: Date.current + 7.days)
    performance.production.update!(production_class: Production::PRIMETIME)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash,
                              performance: performance)
    order.tasks.destroy_all
    order.update_columns(status: status)
    order
  end

  it "creates missing reminders for processed orders with future performances" do
    order = order_missing_tasks
    run_task
    expect(OutreachTask.where(order_id: order.id, method_symbol: 'performance_reminder').count).to eq(1)
  end

  it "creates missing followups for fulfilled orders with future performances" do
    order = order_missing_tasks(status: Order::FULFILLED)
    run_task
    followups = OutreachTask.where(order_id: order.id).select { |t| t.method_symbol&.end_with?('followup') }
    expect(followups.count).to eq(1)
    expect(OutreachTask.where(order_id: order.id, method_symbol: 'performance_reminder').count).to eq(1)
  end

  it "is idempotent" do
    order = order_missing_tasks
    run_task
    expect { run_task }.not_to(change { OutreachTask.where(order_id: order.id).count })
  end

  it "creates nothing under DRY_RUN" do
    order = order_missing_tasks
    ENV['DRY_RUN'] = '1'
    run_task
    expect(OutreachTask.where(order_id: order.id).count).to eq(0)
  end
end
