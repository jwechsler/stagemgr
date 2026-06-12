require 'rails_helper'

RSpec.describe "Production-SeatMap Capacity Integration", type: :model do
  context "capacity logic integration" do
    it "prevents overselling by using actual seat count" do
      # Create a seat map with 50 seats
      seat_map = FactoryBot.create(:seat_map, seat_count: 50)

      # Create a production with higher capacity than seats available
      production = FactoryBot.create(:production, capacity: 200, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      # The capacity should be limited by actual seats, not the database value
      expect(production.capacity).to eq(50)
      expect(production.capacity).to be < 200

      # Verify we can access both values separately
      expect(production.read_attribute(:capacity)).to eq(200)  # database value
      expect(production.seat_map.capacity).to eq(50)           # actual seats
    end

    it "works for general admission (no seat map)" do
      production = FactoryBot.create(:production, capacity: 300)

      # Should use database capacity when no seat map
      expect(production.capacity).to eq(300)
      expect(production.has_general_admission?).to be true
      expect(production.has_reserved_seating?).to be false
    end

    it "switches capacity calculation when seat map is added" do
      production = FactoryBot.create(:production, capacity: 100)

      # Initially uses database capacity
      expect(production.capacity).to eq(100)

      # Add a seat map with fewer seats
      seat_map = FactoryBot.create(:seat_map, seat_count: 75, venue: production.venue)
      production.seat_map = seat_map
      production.save!

      # Now uses seat map capacity
      expect(production.capacity).to eq(75)
      expect(production.has_reserved_seating?).to be true
      expect(production.has_general_admission?).to be false
    end

    it "handles seat map removal gracefully" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 60)
      production = FactoryBot.create(:production, capacity: 120, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      # Uses seat map capacity initially
      expect(production.capacity).to eq(60)

      # Remove seat map
      production.seat_map = nil
      production.save!

      # Falls back to database capacity
      expect(production.capacity).to eq(120)
    end

    it "reflects real-time seat changes" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 30)
      production = FactoryBot.create(:production, capacity: 100, venue: seat_map.venue)
      production.seat_map = seat_map
      production.save!

      expect(production.capacity).to eq(30)

      # Add more seats to the seat map
      FactoryBot.create_list(:seat, 10, seat_map: seat_map)

      # Capacity should reflect the new seat count
      expect(production.capacity).to eq(40)

      # Remove some seats
      seat_map.seats.limit(5).destroy_all

      # Capacity should update accordingly
      expect(production.capacity).to eq(35)
    end
  end
end
