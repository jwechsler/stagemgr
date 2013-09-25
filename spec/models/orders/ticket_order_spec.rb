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

describe "a ticket order" do

  it "can be refunded" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.total.should > 0
    o.refund!
    o.total.should == 0.0
  end

  it "should mark its holder has having attended the production when fulfilled" do
    original_order = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    original_order.transition_to!(Order::FULFILLED)
    original_order.performance.production.attendees.count.should == 1
  end

  it "should unmark the holder has having attended when refunded" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    production = o.performance.production
    o.refund!
    o.performance.production.attendees.count.should == 0
  end

   it "should unmark the holder has having attended when unclaimed" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    o.transition_to!(Order::UNCLAIMED)
    production = o.performance.production
    o.refund!
    o.performance.production.attendees.count.should == 0
  end

  it "should preserve the attendance when cancelling one of multiple reservations" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    a = o.address
    o.transition_to!(Order::FULFILLED)
    o.performance.production.attendees.count.should == 1
    o2 = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o2.address = a
    o2.performance = o.performance
    o2.save!
    o2.transition_to!(Order::FULFILLED)
    o2.performance.production.attendees.count.should == 1
    o2.transition_to!(Order::UNCLAIMED)
    o2.performance.production.attendees.count.should == 1
  end


end
