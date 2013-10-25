require "spec_helper.rb"

describe "a ticket class" do
  before (:each) do
    Authorization.ignore_access_control(true)
    @production = FactoryGirl.create(:production, :capacity=>10)
    @performance = FactoryGirl.create(:performance, :production=>@production)

  end

  after(:each) do
    Authorization.ignore_access_control(false)
  end

  it "knows how many tickets are left for a performance" do
    ticket_class = FactoryGirl.create(:ticket_class, :production=>@production)
    ticket_class.number_left(@performance).should == 10
  end

  it "respects the ticket limit as the production capacity if the ticket class limit is nil" do
    ticket_class = FactoryGirl.create(:ticket_class, :production=>@production)
    @performance.ticket_class_allocations.create(:ticket_class=>ticket_class)
    ticket_class.number_left(@performance).should == 10
  end

  it "limits the ticket class allocation if extant" do
    ticket_class = FactoryGirl.create(:ticket_class, :production=>@production)
    @performance.ticket_class_allocations.create(:ticket_class=>ticket_class, :ticket_limit=>5)
    ticket_class.number_left(@performance).should == 5
  end

  it "should allow ticket types which do not hold seats for performances" do
    ticket_class = FactoryGirl.create(:ticket_class, :production=>@production, :holds_seats=>false)
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.performance.number_of_seats_left.should_not == o.performance.production.capacity
    o.ticket_line_items.first.ticket_class = ticket_class
    o.ticket_line_items.first.save
    o.performance.reload
    o.performance.number_of_seats_left.should == o.performance.production.capacity

  end

end
