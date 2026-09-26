require 'rails_helper'

RSpec.describe Production, 'capacity floor for general admission' do
  let(:production) { FactoryBot.create(:production, capacity: 100) }
  # Distinct dates: the factory's performance times can collide on one day.
  let(:busy_performance) { FactoryBot.create(:performance, production: production, performance_date: Date.current + 10) }
  let(:quiet_performance) { FactoryBot.create(:performance, production: production, performance_date: Date.current + 11) }

  def pair_of_tickets(performance, status: Order::PROCESSED)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, performance: performance)
    order.update_column(:status, status)
    order
  end

  before do
    pair_of_tickets(busy_performance)                      # 2 sold
    pair_of_tickets(busy_performance, status: Order::HOLD) # 2 held
    pair_of_tickets(quiet_performance, status: Order::FULFILLED)
  end

  it 'reports the performance with the most sold and held seats' do
    expect(production.peak_committed_seats).to eq([busy_performance, 4])
  end

  it 'rejects a capacity lower than the busiest performance, naming it' do
    production.capacity = 3

    expect(production).not_to be_valid
    expect(production.errors[:capacity].join)
      .to eq("can't be lower than 4: #{busy_performance.performance_code} already has 4 seats sold or held")
  end

  it 'accepts a capacity equal to the busiest performance' do
    production.capacity = 4

    expect(production).to be_valid
  end

  it 'does not count in-progress or cancelled orders' do
    pair_of_tickets(busy_performance, status: Order::PROCESSING)
    pair_of_tickets(busy_performance, status: Order::CANCELED)
    production.capacity = 4

    expect(production).to be_valid
  end

  it 'does not count tickets in classes that do not hold seats' do
    drink = FactoryBot.create(:ticket_class, production: production, class_code: 'DRINKX', holds_seats: false)
    FactoryBot.create(:ticket_class_allocation, performance: busy_performance, ticket_class: drink, ticket_limit: 50)
    order = pair_of_tickets(busy_performance)
    FactoryBot.create(:ticket_line_item, ticket_class: drink, ticket_count: 10, order: order)
    production.reload.capacity = 6 # 6 seats; the 10 drinks don't count

    expect(production).to be_valid
  end

  it 'does not check a save that leaves capacity alone' do
    production.update_column(:capacity, 1) # already below usage, e.g. legacy data
    production.reload.name = 'Renamed'

    expect(production).to be_valid
  end

  context 'with reserved seating' do
    let(:seat_map) { FactoryBot.create(:seat_map, venue: production.venue, seat_count: 8) }

    it 'ignores the manual capacity while a seat map supplies it' do
      production.update!(seat_map: seat_map)
      production.capacity = 1

      expect(production).to be_valid
    end

    it 'checks the manual capacity again when the seat map is removed' do
      production.update!(seat_map: seat_map)
      production.update_column(:capacity, 2)
      production.reload.seat_map = nil

      expect(production).not_to be_valid
      expect(production.errors[:capacity].join).to include("can't be lower than 4")
    end
  end
end
