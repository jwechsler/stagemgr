require_relative "../../spec_helper.rb"

describe "an exchanged ticket order" do
  it "should have an offset payment" do
    original_order = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    exchange_order = FactoryGirl.create(:ticket_order)
    ticket_line_item = original_order.ticket_line_items.first.dup
    exchange_order.ticket_line_items << ticket_line_item
    exchange_order.exchange_and_process_from! original_order
    exchange_order.payments.count.should == 1
    original_order.payments.count.should == 2
    original_order.status.should == Order::EXCHANGED
    original_order.total.should == 0.0
    exchange_order.total.should == 10.0
    original_order.payments.select {|p| p.is_a? ExchangePayment}.each{|p| p.payment_id.should == exchange_order.payments.first.id}
    exchange_order.payments.each {|p| p.payment_id.should be_in(original_order.payments.map{|op| op.id})}
  end


end
