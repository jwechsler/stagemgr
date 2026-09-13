require 'rails_helper'

# A performance's HouseCount caches production.capacity in total_seats. This job
# is what re-reads capacity for a whole production after either of its sources
# moves: the manual capacity column, or the seat count of an assigned seat map.
RSpec.describe RefreshProductionHouseCountsJob, type: :job do
  let!(:production) { FactoryBot.create(:production, capacity: 100) }
  let!(:performance) { FactoryBot.create(:general_admission, production: production) }
  # A distinct date: performance times round to 15-minute blocks, so two
  # performances created back to back on one day collide on uniqueness.
  let!(:other_performance) do
    FactoryBot.create(:general_admission, production: production, performance_date: Date.current + 1.day)
  end

  it 'recalculates the house count of every performance in the production' do
    production.update_columns(capacity: 60)

    described_class.perform(production.id)

    expect(performance.reload.house_count.total_seats).to eq(60)
    expect(other_performance.reload.house_count.total_seats).to eq(60)
  end

  it 'creates the house count when a performance has none yet' do
    performance.house_count&.destroy!
    production.update_columns(capacity: 60)

    described_class.perform(production.id)

    expect(performance.reload.house_count.total_seats).to eq(60)
  end

  it 'leaves performances of other productions alone' do
    untouched = FactoryBot.create(:general_admission)
    before_total = untouched.house_count.total_seats
    production.update_columns(capacity: 60)

    described_class.perform(production.id)

    expect(untouched.reload.house_count.total_seats).to eq(before_total)
  end

  it 'does nothing when the production no longer exists' do
    expect { described_class.perform(-1) }.not_to raise_error
  end
end
