require "spec_helper.rb"

describe "a payment type" do
  it "can save tasks and methods that should be suppressed" do
    @payment_type = FactoryGirl.create(:external_payment_type, display_name:"Quiet")
    suppress_order_spec = FactoryGirl.create(:order_task_suppression, task_type:'OutreachTask',method_name:'ticket_confirmation')
    @payment_type.order_task_suppressions << suppress_order_spec
    @payment_type.save!
    saved_order_specs = OrderTaskSuppression.find_all_by_payment_type_id(@payment_type.id)
    saved_order_specs.count.should eq(1)
  end
end
