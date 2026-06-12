require 'rails_helper'

RSpec.describe CalculateHouseCountsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  describe '#perform' do
    let!(:performance) {
      FactoryBot.create(:general_admission, performance_date: Date.today)
    } # Uses the general_admission factory
    let!(:ticket_order) {
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, updated_at: 2.days.ago)
    }

    before do
      # Assume last run was yesterday, so only changes within the last day are considered
      travel_to 1.day.ago do
        JobMetadata.record_last_run(described_class.to_s)
      end
    end

    after { travel_back }

    context 'when there are updated ticket orders since the last run' do
      before do
        # Update the ticket order to simulate a recent change
        ticket_order.update!(updated_at: Time.current)
      end

      it 'updates and/or creates house count data from last run' do
        expect(performance.house_count.total_seats).to eq(performance.production.capacity)
        expect(performance.house_count.available_seats).to eq(performance.production.capacity)
        CalculateHouseCountsJob.perform
        performance.reload
        expect(performance.house_count.available_seats).to eq(performance.production.capacity - 2)
      end
    end

    context "when a production's capacity changes" do
      before do
        travel_to 1.hour.ago do
          performance.production.update(capacity: 50)
        end
      end

      it "recalculates house count data" do
        expect(performance.house_count.total_seats).to eq(100)
        CalculateHouseCountsJob.perform
        performance.reload
        expect(performance.house_count.total_seats).to eq(50)
        expect(performance.house_count.available_seats).to eq(performance.production.capacity - 2)
      end
    end

    context 'when there are no updated ticket orders since the last run' do
      it 'does not create or update any house counts' do
        expect(HouseCount).not_to receive(:create)
        CalculateHouseCountsJob.perform
        expect_any_instance_of(HouseCount).not_to receive(:calculate!)
      end
    end
  end
end
