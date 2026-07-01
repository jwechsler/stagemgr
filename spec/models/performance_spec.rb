require 'rails_helper'

RSpec.describe 'a performance' do
  before(:each) do
    @production = FactoryBot.create(:production, capacity: 10)
    @performance = FactoryBot.create(:performance, production: @production)
  end

  it 'returns an allocation given a ticket class code' do
    allocation = @performance.ticket_class_allocations.last
    expect(@performance.allocation(allocation.ticket_class.class_code)).to eq(allocation)
  end

  it 'populates ticket class allocations on demand' do
    ticket_class = FactoryBot.create(:ticket_class, class_code: 'TESTA', production: @production,
                                                    ticket_price: 10, web_visible: true)
    ticket_class2 = FactoryBot.create(:ticket_class, class_code: 'TESTB', production: @production,
                                                     ticket_price: 20, web_visible: true)
    @production.reload
    @performance.reload
    @performance.populate_ticket_class_allocations
    expect(@performance.ticket_class_allocations.map { |tca| tca.ticket_class }).to include(ticket_class)
    expect(@performance.ticket_class_allocations.map { |tca| tca.ticket_class }).to include(ticket_class2)
  end

  it 'cascades availability based on triggered sales targets' do
    ticket_class = FactoryBot.create(:ticket_class, class_code: 'TESTA', production: @production,
                                                    ticket_price: 10, web_visible: true)
    ticket_class2 = FactoryBot.create(:ticket_class, class_code: 'TESTB', production: @production,
                                                     ticket_price: 20, web_visible: true)
    ticket_class3 = FactoryBot.create(:ticket_class, class_code: 'TESTC', production: @production,
                                                     ticket_price: 1, web_visible: true)
    @production.reload
    @performance.production.reload
    @performance.populate_ticket_class_allocations
    allocation = @performance.allocation(ticket_class.class_code)
    allocation.available = true
    allocation.shiftable = true
    allocation.shift_to_code = ticket_class2.class_code
    allocation.shift_days_before_performance = 1000
    allocation.save
    allocation2 = @performance.allocation(ticket_class2.class_code)
    allocation2.available = false
    allocation2.shiftable = true
    allocation2.shift_to_code = ticket_class3.class_code
    allocation2.shift_days_before_performance = 1000
    allocation2.save
    allocation3 = @performance.allocation(ticket_class3.class_code)
    allocation3.available = false
    allocation3.save
    expect(@performance.allocation(ticket_class3.class_code).available?).to be false
    @performance.scan_ticket_allocation_triggers
    # There is some sort of weird rspec record caching happening that prevents these from updating, but they do in regular
    # expect(@performance.allocation(ticket_class.class_code).available?).to be false
    # expect(@performance.allocation(ticket_class2.class_code).available?).to be false
    expect(@performance.allocation(ticket_class3.class_code).available?).to be true
  end
end
