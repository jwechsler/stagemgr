require 'rails_helper'

RSpec.describe OrderTaskSuppression do
  it "prevents order tasks associated with it from firing" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    t = o.tasks.first
    payment_type = o.payment_type
    payment_type.order_task_suppressions << FactoryBot.create(:order_task_suppression,task_type:t.type,method_name:t.method_symbol)
    payment_type.save!
    expect(t.status).to eq(OrderTask::UNTRIED)
    t.run!
    expect(t.status).to eq(OrderTask::CANCELLED)
  end

end
