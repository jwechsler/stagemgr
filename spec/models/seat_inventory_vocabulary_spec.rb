# spec/models/seat_inventory_vocabulary_spec.rb
#
# Characterization specs for the seat-inventory vocabulary facades.
#
# These pin down the contract that the newly introduced, well-named methods
# (seats_occupied, seats_available, seats_on_hold, ...) return *exactly* what
# their pre-existing counterparts return. They are aliases / thin delegators
# with ZERO behavior change, so every assertion compares the new name against
# the old name on the same populated performance.
#
# They also lock in the *intentional* difference between "occupied" (every
# status that ties up a seat) and "on hold" (box-office HOLD only), which is the
# single most confusing point in the seat-inventory code.
require 'rails_helper'

RSpec.describe 'Seat inventory vocabulary facades', type: :model do
  # Build a performance populated with orders in a spread of statuses so the
  # occupied-vs-on-hold distinction is observable:
  #   - 2 PROCESSED (paid / sold) single-ticket orders  -> occupy seats, not on hold
  #   - 1 HOLD single-ticket order                       -> occupies a seat AND is on hold
  #   - 1 NEW (in-progress) single-ticket order          -> occupies a seat, not on hold
  let(:production) { FactoryBot.create(:production, capacity: 50) }
  let(:performance) do
    FactoryBot.create(:general_admission, production: production, performance_date: Date.today)
  end

  before do
    2.times do
      FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card,
                        performance: performance)
    end
    FactoryBot.create(:ticket_order, :for_a_single_ticket, status: Order::HOLD,
                                                           performance: performance)
    FactoryBot.create(:ticket_order, :for_a_single_ticket, status: Order::NEW,
                                                           performance: performance)
  end

  describe 'Order status-set aliases' do
    it 'SEAT_OCCUPYING_STATUSES is the same set as HOLDING_SEAT_STATUSES' do
      expect(Order::SEAT_OCCUPYING_STATUSES).to eq(Order::HOLDING_SEAT_STATUSES)
    end

    it 'ON_HOLD_STATUSES is the same set as HELD_STATUSES' do
      expect(Order::ON_HOLD_STATUSES).to eq(Order::HELD_STATUSES)
    end

    it 'keeps the two concepts distinct: occupying is broader than on-hold' do
      expect(Order::SEAT_OCCUPYING_STATUSES).to include(*Order::ON_HOLD_STATUSES)
      expect(Order::SEAT_OCCUPYING_STATUSES.size).to be > Order::ON_HOLD_STATUSES.size
    end
  end

  describe 'Performance facades' do
    it 'seats_occupied returns exactly seats_held' do
      expect(performance.seats_occupied).to eq(performance.seats_held)
    end

    it 'seats_occupied counts every seat-occupying status (sold + hold + in-progress)' do
      # 2 PROCESSED + 1 HOLD + 1 NEW single tickets = 4 occupied seats
      expect(performance.seats_occupied).to eq(4)
    end

    it 'seats_available returns exactly number_of_seats_left' do
      expect(performance.seats_available).to eq(performance.number_of_seats_left)
    end

    it 'seats_available equals capacity minus seats_occupied' do
      expect(performance.seats_available).to eq(production.capacity - performance.seats_occupied)
    end

    it 'forwards the exclude_order argument the same way as the legacy methods' do
      excluded = performance.orders.detect { |o| o.status == Order::HOLD }
      expect(performance.seats_occupied(excluded)).to eq(performance.seats_held(excluded))
      expect(performance.seats_available(excluded)).to eq(performance.number_of_seats_left(excluded))
    end
  end

  describe 'TicketOrder#occupies_seats?' do
    it 'returns exactly what holding_seats? returns for each status' do
      performance.orders.each do |order|
        expect(order.occupies_seats?).to eq(order.holding_seats?)
      end
    end

    it 'is true for an occupying status and false for a non-occupying one' do
      hold_order = performance.orders.detect { |o| o.status == Order::HOLD }
      expect(hold_order.occupies_seats?).to be(true)

      hold_order.update_column(:status, Order::CANCELED)
      expect(hold_order.occupies_seats?).to be(false)
    end
  end

  describe 'HouseCount reader facades' do
    let(:house_count) do
      hc = HouseCount.new(performance: performance)
      hc.calculate
      hc
    end

    it 'seats_on_hold returns exactly held_seats' do
      expect(house_count.seats_on_hold).to eq(house_count.held_seats)
    end

    it 'seats_sold returns exactly sold_seats' do
      expect(house_count.seats_sold).to eq(house_count.sold_seats)
    end

    it 'seats_available returns exactly available_seats' do
      expect(house_count.seats_available).to eq(house_count.available_seats)
    end

    it 'seats_total returns exactly total_seats' do
      expect(house_count.seats_total).to eq(house_count.total_seats)
    end
  end

  describe 'documented relationships (live Performance vs cached HouseCount)' do
    before do
      performance.create_house_count
      performance.house_count.calculate!
    end

    it 'house_count.available_seats == capacity - performance.seats_occupied after calculate!' do
      expect(performance.house_count.available_seats)
        .to eq(production.capacity - performance.seats_occupied)
    end

    it 'held_seats counts ONLY box-office HOLD orders' do
      # Exactly one HOLD order with one ticket was created above.
      expect(performance.house_count.held_seats).to eq(1)
    end

    it 'seats_occupied counts ALL occupying statuses, strictly more than held_seats' do
      expect(performance.seats_occupied).to eq(4)
      expect(performance.seats_occupied).to be > performance.house_count.held_seats
    end
  end
end
