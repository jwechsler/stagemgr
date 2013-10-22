require "spec_helper.rb"

describe "a performance" do

  before (:each) do
    Authorization.ignore_access_control(true)
    @production = FactoryGirl.create(:production, :capacity=>10)
    @performance = FactoryGirl.create(:performance, :production=>@production)
  end

  it "returns an allocation given a ticket class code" do
    allocation = @performance.ticket_class_allocations.last
    @performance.allocation(allocation.ticket_class.class_code).should eq(allocation)
  end

  it "populates ticket class allocations on demand" do
    ticket_class = FactoryGirl.create(:ticket_class, :class_code=>'TESTA',:production=>@production,
      :ticket_price=>10, :web_visible=>true)
    ticket_class2 = FactoryGirl.create(:ticket_class, :class_code=>'TESTB', :production=>@production,
      :ticket_price=>20, :web_visible=>true)
    @production.reload
    @performance.reload
    @performance.populate_ticket_class_allocations
    @performance.ticket_class_allocations.map{|tca| tca.ticket_class }.should include(ticket_class)
    @performance.ticket_class_allocations.map{|tca| tca.ticket_class }.should include(ticket_class2)
  end

  it "can shift associations based on triggered events" do
    ticket_class = FactoryGirl.create(:ticket_class, :class_code=>'TESTA',:production=>@production,
      :ticket_price=>10, :web_visible=>true)
    ticket_class2 = FactoryGirl.create(:ticket_class, :class_code=>'TESTB', :production=>@production,
      :ticket_price=>20, :web_visible=>true)
    @production.reload
    @performance.production.reload
    @performance.populate_ticket_class_allocations
    allocation = @performance.allocation(ticket_class.class_code)
    allocation.available = true
    allocation.shiftable = true
    allocation.shift_to_code = ticket_class2.class_code
    allocation.save
    allocation2 = @performance.allocation(ticket_class2.class_code)
    allocation2.available = false
    allocation2.save
    @performance.ticket_class_allocations.each {|tca| tca.trigger_shift if tca.shiftable? }
    @performance.ticket_class_allocations(true)
    original_allocation = @performance.allocation(ticket_class.class_code)
    original_allocation.available.should eq(false)
    new_allocation = @performance.allocation(ticket_class2.class_code)
    new_allocation.available.should eq(true)
  end

end