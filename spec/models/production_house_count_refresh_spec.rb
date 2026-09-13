require 'rails_helper'

# Production#capacity feeds every performance's HouseCount, but the scheduled
# CalculateHouseCountsJob sweep only revisits a production for two days after
# its row changes and compares cached totals one performance at a time. A
# capacity edit must queue its own refresh so the change lands promptly.
RSpec.describe Production, 'house count refresh', type: :model do
  let!(:production) { FactoryBot.create(:production, capacity: 100) }

  before { allow(Resque).to receive(:enqueue) }

  it 'queues a refresh when the manual capacity changes' do
    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)

    production.update!(capacity: 60)
  end

  it 'queues a refresh when the seat map supplying capacity is assigned' do
    seat_map = FactoryBot.create(:seat_map, venue: production.venue, seat_count: 12)
    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)

    production.update!(seat_map: seat_map)
  end

  it 'queues a refresh when the seat map is removed and capacity reverts' do
    seat_map = FactoryBot.create(:seat_map, venue: production.venue, seat_count: 12)
    production.update!(seat_map: seat_map)

    expect(Resque).to receive(:enqueue).with(RefreshProductionHouseCountsJob, production.id)
    production.update!(seat_map: nil)
  end

  it 'does not queue a refresh for edits that leave capacity alone' do
    expect(Resque).not_to receive(:enqueue).with(RefreshProductionHouseCountsJob, anything)

    production.update!(running_time: 95)
  end
end
