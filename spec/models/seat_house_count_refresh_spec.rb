require 'rails_helper'

# SeatMap#capacity is seats.count, so adding or removing a seat changes the
# effective capacity of every production using that map -- without touching any
# production or order row. Nothing the CalculateHouseCountsJob sweep looks at
# moves, so the seat itself has to queue the refresh.
RSpec.describe Seat, 'house count refresh', type: :model do
  let!(:venue) { FactoryBot.create(:venue) }
  let!(:seat_map) { FactoryBot.create(:seat_map, venue: venue, seat_count: 4) }
  let!(:production) { FactoryBot.create(:production, venue: venue, seat_map: seat_map) }

  before { allow(Resque).to receive(:enqueue) }

  it 'queues a refresh for each production using the map when a seat is added' do
    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)

    FactoryBot.create(:seat, seat_map: seat_map)
  end

  it 'queues a refresh when a seat is removed' do
    seat = seat_map.seats.last
    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)

    seat.destroy!
  end

  it 'queues a refresh for every production sharing the seat map' do
    second = FactoryBot.create(:production, venue: venue, seat_map: seat_map)

    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)
    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, second.id)

    FactoryBot.create(:seat, seat_map: seat_map)
  end

  it 'does not queue a refresh for geometry or zone edits that leave the count alone' do
    seat = seat_map.seats.first

    expect(Resque).not_to receive(:enqueue).with(RefreshProductionHouseCountsJob, anything)
    seat.update!(origin_x: 42, zone: 'B')
  end

  it 'does not queue a refresh when no production uses the seat map' do
    unused_map = FactoryBot.create(:seat_map, venue: venue, seat_count: 0)

    expect(Resque).not_to receive(:enqueue).with(RefreshProductionHouseCountsJob, anything)
    FactoryBot.create(:seat, seat_map: unused_map)
  end
end
