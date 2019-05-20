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
      seatmap = FactoryBot.create(:seat_map)
      8.times do
       seat = FactoryBot.create(:seat)
       # seat.seat_map = seatmap
       seatmap.seats << seat
      end

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

  context "inventory management" do
    before(:each) do
      @seat_map = FactoryBot.create(:seat_map_with_seats)

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

