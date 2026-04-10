# spec/models/house_count_spec.rb
require 'rails_helper'

RSpec.describe HouseCount, type: :model do
  describe 'House Count Calculations' do
    it 'correctly calculates total, sold, and available seats for a general admission performance' do
      # Create a general admission production with a specified capacity
      production = FactoryBot.create(:production, capacity: 50)

      # Create a general admission performance linked to this production
      performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

      # Create 6 tickets sold for the performance using the single ticket trait
      6.times do
        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)
      end

      FactoryBot.create(:ticket_order, :for_three_tickets, performance: performance)

      # Initialize the HouseCount record associated with the performance
      house_count = HouseCount.new(performance: performance)
      house_count.calculate  # This method should calculate total, sold, and available seats

      # Validate the HouseCount calculations
      expect(house_count.total_seats).to eq(50)
      expect(house_count.sold_seats).to eq(6)  # Since each order includes 1 ticket
      expect(house_count.available_seats).to eq(41)  # Total seats minus held seats
    end

    describe '#calculate_held_seats' do
      it 'counts tickets on Hold-status orders where the ticket class holds_seats' do
        production = FactoryBot.create(:production, capacity: 50)
        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        # Create a Hold order explicitly
        hold_order = FactoryBot.create(:ticket_order, :for_a_single_ticket, status: Order::HOLD, performance: performance)
        expect(hold_order.status).to eq(Order::HOLD)

        # Create a sold (Processed) order — should not count toward held_seats
        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        # Only the 1 ticket from the Hold order should count as held
        expect(house_count.held_seats).to eq(1)
      end

      it 'returns 0 when there are no Hold-status orders' do
        production = FactoryBot.create(:production, capacity: 50)
        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        expect(house_count.held_seats).to eq(0)
      end
    end

    describe '#calculate_max_ticket_price' do
      it 'returns the highest ticket price among available, web_visible, show_in_pricing_range ticket classes' do
        production = FactoryBot.create(:production, capacity: 50)

        cheap_class = FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 15.00,
          web_visible: true,
          show_in_pricing_range: true,
          auto_attach: true)

        expensive_class = FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 40.00,
          web_visible: true,
          show_in_pricing_range: true,
          auto_attach: true)

        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        expect(house_count.max_ticket_price).to eq(40.00)
      end

      it 'excludes ticket classes that are not web_visible' do
        production = FactoryBot.create(:production, capacity: 50)

        FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 20.00,
          web_visible: true,
          show_in_pricing_range: true,
          auto_attach: true)

        FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 99.00,
          web_visible: false,
          show_in_pricing_range: true,
          auto_attach: true)

        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        expect(house_count.max_ticket_price).to eq(20.00)
      end

      it 'excludes ticket classes where show_in_pricing_range is false' do
        production = FactoryBot.create(:production, capacity: 50)

        FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 25.00,
          web_visible: true,
          show_in_pricing_range: true,
          auto_attach: true)

        FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 75.00,
          web_visible: true,
          show_in_pricing_range: false,
          auto_attach: true)

        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        expect(house_count.max_ticket_price).to eq(25.00)
      end

      it 'returns nil when no eligible ticket classes exist' do
        production = FactoryBot.create(:production, capacity: 50)
        production.ticket_classes.update_all(web_visible: false)

        FactoryBot.create(:ticket_class,
          production: production,
          ticket_price: 50.00,
          web_visible: false,
          show_in_pricing_range: true,
          auto_attach: true)

        performance = FactoryBot.create(:general_admission, production: production, performance_date: Date.today)

        house_count = HouseCount.new(performance: performance)
        house_count.calculate

        expect(house_count.max_ticket_price).to be_nil
      end
    end

    describe '.export_columns' do
      it 'includes held_seats and max_ticket_price' do
        expect(HouseCount.export_columns).to include('held_seats', 'max_ticket_price')
      end
    end
  end
end
