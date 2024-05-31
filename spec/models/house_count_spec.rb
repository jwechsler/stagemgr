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
      puts house_count.to_yaml
      expect(house_count.total_seats).to eq(50)
      expect(house_count.sold_seats).to eq(6)  # Since each order includes 1 ticket
      expect(house_count.available_seats).to eq(41)  # Total seats minus held seats 
    end
  end
end
