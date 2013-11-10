require "spec_helper.rb"

describe "a customer record" do
  it "should merge/purge production attendance records" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    original_address = o.address
    original_address.productions.count.should == 1
    o2 = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o2.performance.production_id.should_not == o.performance.production_id
    purge_address = original_address.dup
    purge_address.full_name = purge_address.full_name + "-updated"
    purge_address.save
    o2.address = purge_address
    o2.transition_to!(Order::FULFILLED)
    purge_address.productions.count.should == 1
    original_address.merge_and_purge(purge_address)
    original_address.last_name.should =~ /(.*)-Updated/
    original_address.productions.count.should == 2
  end
end
