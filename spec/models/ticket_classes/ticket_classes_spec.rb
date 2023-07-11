require 'rails_helper'

RSpec.describe TicketClass do
  before (:each) do
    @production = FactoryBot.create(:production, :capacity=>10)
    @performance = FactoryBot.create(:performance, :production=>@production)

  end

  it "knows how many tickets are left for a performance" do
    ticket_class = FactoryBot.create(:ticket_class, :production=>@production)
    @performance.ticket_class_allocations.create(:ticket_class=>ticket_class)
    expect(ticket_class.number_left(@performance)).to eq(10)
  end

  it "respects the ticket limit as the production capacity if the ticket class limit is nil" do
    ticket_class = FactoryBot.create(:ticket_class, :production=>@production)
    @performance.ticket_class_allocations.create(:ticket_class=>ticket_class)
    expect(ticket_class.number_left(@performance)).to eq(10)
  end

  it "limits the ticket class allocation if extant" do
    ticket_class = FactoryBot.create(:ticket_class, :production=>@production)
    @performance.ticket_class_allocations.create(:ticket_class=>ticket_class, :ticket_limit=>5)
    expect(ticket_class.number_left(@performance)).to eq(5)
  end

  it "should allow ticket types which do not hold seats for performances" do
    ticket_class = FactoryBot.create(:ticket_class, :production=>@production, :holds_seats=>false)
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    expect(o.performance.number_of_seats_left).not_to eq(o.performance.production.capacity)
    o.ticket_line_items.first.ticket_class = ticket_class
    o.ticket_line_items.first.save
    o.performance.reload
    expect(o.performance.number_of_seats_left).to eq(o.performance.production.capacity)
  end

  it "should only attach to performances when auto attach is checked" do
    ticket_class = FactoryBot.create(:ticket_class, production: @production, auto_attach: false)
    @performance.reload
    tca_for_performance = @performance.ticket_class_allocations.select{|tca| tca.ticket_class.eql? ticket_class}
    expect(tca_for_performance.count).to eq(1)
    expect(tca_for_performance.map{|tca| tca.ticket_class}).to include(ticket_class)
    expect(tca_for_performance.first.available?).to be false
    ticket_class.auto_attach = true
    expect(ticket_class.save).to be true
    @performance.reload
    tca_for_performance = @performance.ticket_class_allocations.select{|tca| tca.ticket_class.eql? ticket_class}
    expect(tca_for_performance.count).to eq(1)
    expect(tca_for_performance.map{|tca| tca.ticket_class}).to include(ticket_class)
    expect(tca_for_performance.first.available?).to be true
    

  end
end
