require 'rails_helper'

RSpec.describe ProjectHouseCountsJob, type: :job do
  let(:production) { FactoryBot.create(:production) }
  let!(:active_performance) do
    FactoryBot.create(:performance, production: production, performance_date: Date.current + 10.days)
  end
  let!(:private_performance) do
    FactoryBot.create(:performance, production: production, performance_date: Date.current + 11.days,
                                    status: Performance::PRIVATE)
  end
  let(:reading) do
    AdvanceSalesPace::Reading.new(performance_id: active_performance.id, days_out: 10, sold: 12,
                                  typical_share: BigDecimal('0.4'), projected_final: 30, capacity: 100,
                                  projected_pct_of_capacity: 0.3, source: :theater)
  end

  before do
    allow(AdvanceSalesPace).to receive(:for_productions)
      .and_return({ active_performance.id => reading })
  end

  it 'writes the pace snapshot onto an upcoming Active performance house count' do
    described_class.perform

    house_count = active_performance.house_count.reload
    expect(house_count).to have_attributes(projected_seats: 30, pace_share: BigDecimal('0.4'), pace_sold: 12,
                                           pace_source: 'theater', pace_as_of: Date.current)
  end

  it 'leaves the projection nil but stamps pace_as_of for a Private performance' do
    described_class.perform

    house_count = private_performance.house_count.reload
    expect(house_count).to have_attributes(projected_seats: nil, pace_share: nil, pace_sold: nil,
                                           pace_source: nil, pace_as_of: Date.current)
  end

  it 'clears a stale projection when the performance no longer has a reading' do
    private_performance.house_count.update_columns(projected_seats: 99, pace_as_of: Date.current - 1.day)

    described_class.perform

    expect(private_performance.house_count.reload).to have_attributes(projected_seats: nil, pace_as_of: Date.current)
  end

  it 'does not change sold, held or available seats' do
    active_performance.house_count.update_columns(sold_seats: 7, held_seats: 3, available_seats: 41)

    described_class.perform

    expect(active_performance.house_count.reload)
      .to have_attributes(sold_seats: 7, held_seats: 3, available_seats: 41)
  end

  it 'skips a performance with no house count row and creates none' do
    active_performance.house_count.destroy!

    expect { described_class.perform }.not_to change(HouseCount, :count)
    expect(HouseCount.find_by(performance_id: active_performance.id)).to be_nil
  end

  it 'leaves past performances untouched' do
    past = FactoryBot.create(:performance, production: production, performance_date: Date.current - 1.day)

    described_class.perform

    expect(past.house_count.reload.pace_as_of).to be_nil
  end

  it 'calls AdvanceSalesPace.for_productions once for the whole pass' do
    other = FactoryBot.create(:performance, production: FactoryBot.create(:production),
                                            performance_date: Date.current + 5.days)

    described_class.perform

    expect(AdvanceSalesPace).to have_received(:for_productions).once
    expect(AdvanceSalesPace).to have_received(:for_productions)
      .with(contain_exactly(production, other.production), as_of: Date.current)
  end

  it 'logs a failed row and still writes the others' do
    allow(Rails.logger).to receive(:error)
    allow_any_instance_of(HouseCount).to receive(:save!).and_wrap_original do |original, *args|
      raise ActiveRecord::RecordInvalid if original.receiver.performance_id == private_performance.id

      original.call(*args)
    end

    described_class.perform

    expect(Rails.logger).to have_received(:error).with(/#{private_performance.performance_code}/)
    expect(active_performance.house_count.reload.projected_seats).to eq(30)
  end
end
