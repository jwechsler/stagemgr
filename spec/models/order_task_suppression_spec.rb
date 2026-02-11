require 'rails_helper'

RSpec.describe OrderTaskSuppression do
  let(:order)        { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }
  let(:task)         { order.tasks.first }
  let(:payment_type) { order.payment_type }

  def add_suppression(trait = nil, overrides = {})
    attrs = { task_type: task.type, method_name: task.method_symbol }.merge(overrides)
    suppression = if trait
                    FactoryBot.create(:order_task_suppression, trait, **attrs)
                  else
                    FactoryBot.create(:order_task_suppression, **attrs)
                  end
    payment_type.order_task_suppressions << suppression
    payment_type.save!
  end

  it "suppresses a task with exact task_type and method_name match" do
    add_suppression
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).to eq(OrderTask::CANCELLED)
  end

  it "suppresses all methods of a task type when method_name is ANY" do
    add_suppression(:any_method)
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).to eq(OrderTask::CANCELLED)
  end

  it "does not suppress a different task type even with ANY wildcard" do
    add_suppression(:any_method, task_type: "NonExistentTask")
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).not_to eq(OrderTask::CANCELLED)
  end

  it "does not suppress when method_name does not match" do
    add_suppression(nil, method_name: "some_other_method")
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).not_to eq(OrderTask::CANCELLED)
  end

  it "does not suppress when task_type does not match" do
    add_suppression(nil, task_type: "NonExistentTask")
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).not_to eq(OrderTask::CANCELLED)
  end

  it "runs task normally when no suppressions exist" do
    expect(payment_type.order_task_suppressions).to be_empty
    expect(task.status).to eq(OrderTask::UNTRIED)
    task.run!
    expect(task.status).not_to eq(OrderTask::CANCELLED)
  end
end
