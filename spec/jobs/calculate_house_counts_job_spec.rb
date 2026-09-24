require 'rails_helper'

RSpec.describe CalculateHouseCountsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  # Expressed against the job's own constants so these move with them. The
  # offsets keep each side of the boundary unambiguous.
  let(:inside_window) { described_class::SWEEP_LOOKBACK.ago + 1.hour }
  let(:outside_window) { described_class::SWEEP_LOOKBACK.ago - 1.day }

  def record_sweep_watermark(at)
    JobMetadata.find_or_initialize_by(job_name: described_class::SWEEP_WATERMARK)
               .update!(last_run_at: at)
  end

  describe '#perform' do
    # Uses the general_admission factory
    let!(:performance) do
      FactoryBot.create(:general_admission, performance_date: Date.current)
    end
    let!(:ticket_order) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, updated_at: inside_window)
    end
    # A figure calculate! would never produce, so it surviving a run proves the
    # performance was not recalculated.
    let(:stale_available_seats) { 7 }

    context 'when orders changed inside the sweep window' do
      before do
        # Update the ticket order to simulate a recent change
        ticket_order.update!(updated_at: Time.current)
      end

      it 'updates and/or creates house count data' do
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

      it 'recalculates house count data' do
        expect(performance.house_count.total_seats).to eq(100)
        CalculateHouseCountsJob.perform
        performance.reload
        expect(performance.house_count.total_seats).to eq(50)
        expect(performance.house_count.available_seats).to eq(performance.production.capacity - 2)
      end
    end

    context 'when the worker was down for longer than the lookback' do
      # The case a fixed window cannot serve: an order changed during the
      # outage, outside SWEEP_LOOKBACK but after the last successful sweep.
      let(:outage_length) { described_class::SWEEP_LOOKBACK + 3.days }

      before do
        record_sweep_watermark(outage_length.ago)
        ticket_order.update_columns(updated_at: (outage_length - 1.day).ago)
        performance.production.update_columns(updated_at: outage_length.ago)
        performance.house_count.update_columns(available_seats: stale_available_seats)
      end

      it 'reaches back to the last successful sweep and catches up' do
        described_class.perform

        expect(performance.house_count.reload.available_seats)
          .to eq(performance.production.capacity - 2)
      end
    end

    context 'when the last sweep is older than the ceiling' do
      before do
        record_sweep_watermark((described_class::MAX_SWEEP_LOOKBACK + 10.days).ago)
        ticket_order.update_columns(updated_at: (described_class::MAX_SWEEP_LOOKBACK + 5.days).ago)
        performance.production.update_columns(updated_at: (described_class::MAX_SWEEP_LOOKBACK + 5.days).ago)
        performance.house_count.update_columns(available_seats: stale_available_seats)
      end

      it 'does not reach back past MAX_SWEEP_LOOKBACK' do
        described_class.perform

        expect(performance.house_count.reload.available_seats).to eq(stale_available_seats)
      end
    end

    describe 'the sweep watermark' do
      # last_run_at is DATETIME(0), so stored values lose sub-second precision.
      it 'is recorded after a successful sweep' do
        freeze_time do
          described_class.perform

          expect(JobMetadata.last_run(described_class::SWEEP_WATERMARK))
            .to be_within(1.second).of(Time.current)
        end
      end

      it 'is not advanced by a targeted per-performance refresh' do
        # TicketOrder queues these on every status change; if they moved the
        # sweep's watermark the sweep would skip orders it never examined.
        record_sweep_watermark(outside_window)

        expect { described_class.perform(performance.id) }
          .not_to(change { JobMetadata.last_run(described_class::SWEEP_WATERMARK) })
      end

      it 'stays put when the sweep raises partway through' do
        record_sweep_watermark(outside_window)
        allow(Production).to receive(:where).and_raise(ActiveRecord::StatementInvalid)

        expect { described_class.perform }.to raise_error(ActiveRecord::StatementInvalid)
        expect(JobMetadata.last_run(described_class::SWEEP_WATERMARK))
          .to be_within(1.second).of(outside_window)
      end
    end

    context 'when no orders changed inside the sweep window' do
      before do
        # A recent sweep, so the window is the SWEEP_LOOKBACK floor rather than
        # the catch-up ceiling an absent watermark would produce.
        record_sweep_watermark(1.hour.ago)
        # update_columns so moving the rows out of the window does not itself
        # bump updated_at back into it.
        ticket_order.update_columns(updated_at: outside_window)
        # The capacity backstop would otherwise pick this production up; it has
        # its own context above.
        performance.production.update_columns(updated_at: outside_window)
        performance.house_count.update_columns(available_seats: stale_available_seats)
      end

      it 'leaves the cached house count untouched' do
        described_class.perform

        expect(performance.house_count.reload.available_seats).to eq(stale_available_seats)
      end
    end
  end

  describe '.perform with a performance id' do
    let!(:performance) { FactoryBot.create(:general_admission, performance_date: Date.current) }
    let!(:ticket_order) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, updated_at: outside_window)
    end

    it 'recalculates that performance even when none of its orders changed recently' do
      expect(performance.house_count.available_seats).to eq(performance.production.capacity)
      CalculateHouseCountsJob.perform(performance.id)
      expect(performance.reload.house_count.available_seats).to eq(performance.production.capacity - 2)
    end

    it 'creates the house count when the performance has none yet' do
      performance.house_count.destroy!
      CalculateHouseCountsJob.perform(performance.id)
      expect(performance.reload.house_count.available_seats).to eq(performance.production.capacity - 2)
    end

    it 'does nothing when the performance no longer exists' do
      expect { CalculateHouseCountsJob.perform(-1) }.not_to raise_error
    end
  end
end
