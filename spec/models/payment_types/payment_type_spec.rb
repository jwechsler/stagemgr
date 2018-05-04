require "spec_helper.rb"

describe "a payment type"  do
  it "can save tasks and methods that should be suppressed" do
    @payment_type = FactoryBot.create(:external_payment_type, display_name:"Quiet")
    suppress_order_spec = FactoryBot.create(:order_task_suppression, task_type:'OutreachTask',method_name:'ticket_confirmation')
    @payment_type.order_task_suppressions << suppress_order_spec
    @payment_type.save!
    saved_order_specs = OrderTaskSuppression.where(payment_type_id:@payment_type.id)
    expect(saved_order_specs.size).to eq(1)
  end
end
