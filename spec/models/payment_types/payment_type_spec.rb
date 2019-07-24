require 'rails_helper'

RSpec.describe "a payment type"  do
  it "can save tasks and methods that should be suppressed" do
    @payment_type = FactoryBot.create(:external_payment_type)
    suppress_order_spec = FactoryBot.create(:order_task_suppression, task_type:'OutreachTask',method_name:'ticket_confirmation')
    @payment_type.order_task_suppressions << suppress_order_spec
    @payment_type.save!
    saved_order_specs = OrderTaskSuppression.where(payment_type_id:@payment_type.id)
    expect(saved_order_specs.size).to eq(1)
  end

  it "can specify if it should be used in sales reporting" do
    production = FactoryBot.create(:production, :capacity=>4)
    performance = FactoryBot.create(:performance, :production=>production)
    production.reload
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :performance=>performance )
    order.payment_type = CashPaymentType.first
    order.transition_to!(Order::PROCESSED)
    report = SalesByPerformanceReport.new([production], false)
    @headers, @report_data = report.create
    expect(@report_data[0][:gross].to_f).to eq(10.0)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :performance=>performance )
    payment_type = FactoryBot.create(:external_payment_type)
    payment_type.report_as_sales_income = false
    payment_type.save!
    order.payment_type = payment_type
    order.transition_to!(Order::PROCESSED)
    production.reload
    report = SalesByPerformanceReport.new([production], false)
    @headers, @report_data = report.create
    expect(@report_data[0][:gross].to_f).to eq(10.0)
  end

  it "can restrict purchases based on a comma-delimited set of ticket class strings", :wip=>true do
    payment_type = FactoryBot.create(:external_payment_type, :display_name=>'TEST', :allow_for_public=>false, :allow_for_box_office=>true, :restrict_to_ticket_classes=>'HOTTIX,CHEAP')
    production = FactoryBot.create(:production, :capacity=>4)
    production.ticket_classes << FactoryBot.create(:ticket_class, class_code: "CHEAP", ticket_price: 1.0, auto_attach:true)
    performance = FactoryBot.create(:performance, :production=>production)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :performance=>performance )
    order.payment_type = payment_type
    expect { order.transition_to!(Order::PROCESSED)}.to raise_error(RuntimeError)
    order = FactoryBot.create(:ticket_order, :for_a_cheap_pair_of_tickets, :performance=>performance )
    order.payment_type = payment_type
    order.transition_to!(Order::PROCESSED)
    expect(order.status).to eq(Order::PROCESSED)

  end

end
