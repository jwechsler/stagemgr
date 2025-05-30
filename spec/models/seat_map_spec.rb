require 'rails_helper'

RSpec.describe SeatMap, type: :model do
  context "creation" do

    it "can be assigned to a venue" do
      @venue = FactoryBot.create(:venue)
      seatmap = FactoryBot.create(:seat_map, venue:@venue)
      seatmap.venue = @venue
      seatmap.save
      expect(seatmap.venue).to eq(@venue)
      @venue.reload
      expect(@venue.seat_maps).to include(seatmap)
    end

    it "can be assigned seats" do
      seatmap = FactoryBot.create(:seat_map, seat_count:8)

      expect(seatmap.seats.count).to eq(8)

    end

    it "can be assigned to a production in that venue" do
      seat_map = FactoryBot.create(:seat_map)
      production = FactoryBot.create(:production, venue: seat_map.venue)
      production.seat_map = seat_map
      expect(production.save).to be true
    end

    it "cannot be assigned to a production in a different venue" do
      seat_map = FactoryBot.create(:seat_map)
      venue = FactoryBot.create(:venue)
      production = FactoryBot.create(:production, venue: venue)
      production.seat_map = seat_map
      expect(production.save).to be false
    end


  end

  context "capacity logic" do
    it "returns the count of seats" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 12)
      expect(seat_map.capacity).to eq(12)
    end

    it "returns 0 when no seats exist" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 0)
      expect(seat_map.capacity).to eq(0)
    end

    it "dynamically counts seats if seats are added later" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 5)
      expect(seat_map.capacity).to eq(5)
      
      # Add more seats
      FactoryBot.create_list(:seat, 3, seat_map: seat_map)
      expect(seat_map.capacity).to eq(8)
    end

    it "updates capacity when seats are removed" do
      seat_map = FactoryBot.create(:seat_map, seat_count: 10)
      expect(seat_map.capacity).to eq(10)
      
      # Remove some seats
      seat_map.seats.limit(3).destroy_all
      expect(seat_map.capacity).to eq(7)
    end
  end

  context "inventory management" do
    before(:each) do
      @seat_map = FactoryBot.create(:seat_map)

    end

    it "automatically creates seating inventory on performance save if necessary" do
      production = FactoryBot.create(:production, venue: @seat_map.venue)
      performance = FactoryBot.create(:performance, production: production)
      expect(performance.seat_assignments.count).to eq(0)
      production.seat_map = @seat_map
      production.save
      performance.reload
      performance.save
      expect(performance.seat_assignments.count).to eq(8)
    end

  end
end

