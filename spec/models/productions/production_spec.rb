require_relative "../../spec_helper.rb"

describe "a production" do
  context "with one order" do
    it "should have one attendee when fulfilled" do
      ticket_order = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
      ticket_order.performance.production.attendees.count.should == 0
      ticket_order.transition_to!(Order::FULFILLED)
      ticket_order.performance.production.attendees.count.should == 1
    end
  end
end
