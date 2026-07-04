require 'rails_helper'

RSpec.describe SyncTicketClassAllocationsJob, type: :job do
  before(:each) do
    @production = FactoryBot.create(:production, capacity: 10)
    @performance = FactoryBot.create(:performance, production: @production, performance_date: Date.tomorrow)
    # Production setup auto-creates default ticket classes whose callbacks bump
    # the counter; zero it so the examples measure only their own syncs.
    @production.update_column(:allocation_sync_pending_count, 0)
  end

  def pending_count
    @production.reload.allocation_sync_pending_count
  end

  describe '.perform' do
    it 'creates allocations for future performances and releases the pending counter' do
      ticket_class = FactoryBot.create(:ticket_class, production: @production)
      expect(pending_count).to eq(1) # incremented by the enqueue callback

      described_class.perform(ticket_class.id, @production.id)

      tca = @performance.ticket_class_allocations.find_by(ticket_class: ticket_class)
      expect(tca).to be_present
      expect(tca.available?).to be true
      expect(pending_count).to eq(0)
    end

    it 'releases the pending counter even when the sync raises' do
      ticket_class = FactoryBot.create(:ticket_class, production: @production)
      expect(pending_count).to eq(1)
      allow(TicketClassAllocation).to receive(:find_or_initialize_by).and_raise(StandardError, 'boom')

      expect do
        described_class.perform(ticket_class.id, @production.id)
      end.to raise_error(StandardError, 'boom')

      expect(pending_count).to eq(0)
    end

    it 'releases the pending counter when the ticket class no longer exists' do
      ticket_class = FactoryBot.create(:ticket_class, production: @production)
      expect(pending_count).to eq(1)
      ticket_class_id = ticket_class.id
      ticket_class.delete # bypass destroy guards; only the row's absence matters here

      described_class.perform(ticket_class_id, @production.id)

      expect(pending_count).to eq(0)
    end

    it 'derives the production from the ticket class for legacy single-argument payloads' do
      ticket_class = FactoryBot.create(:ticket_class, production: @production)
      expect(pending_count).to eq(1)

      described_class.perform(ticket_class.id)

      expect(pending_count).to eq(0)
    end
  end

  describe 'Production#mark_allocation_sync_completed!' do
    it 'never drives the pending counter below zero' do
      expect(pending_count).to eq(0)
      @production.mark_allocation_sync_completed!
      expect(pending_count).to eq(0)
    end
  end
end
