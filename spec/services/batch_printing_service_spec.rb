require 'rails_helper'

RSpec.describe BatchPrintingService, type: :service do
  describe '.create_and_process_batch' do
    let(:performance) { FactoryBot.create(:performance) }
    let(:orders) { FactoryBot.create_list(:ticket_order, 3, performance: performance) }

    before do
      allow(Resque).to receive(:enqueue)
    end

    context 'with valid orders' do
      it 'creates a batch with generated ID' do
        batch_id = BatchPrintingService.create_and_process_batch(orders)
        
        expect(batch_id).to match(/\d{8}_\d{6}_[a-f0-9]{8}/)
      end

      it 'enqueues a PrintBatchJob with batch_id and order_ids' do
        batch_id = BatchPrintingService.create_and_process_batch(orders)
        
        expect(Resque).to have_received(:enqueue).with(
          PrintBatchJob, 
          batch_id, 
          orders.map(&:id)
        )
      end

      it 'logs the batch creation' do
        expect(Rails.logger).to receive(:info).with(/Creating bulk batch with orders:/)
        
        BatchPrintingService.create_and_process_batch(orders)
      end
    end

    context 'with empty orders' do
      it 'returns false' do
        result = BatchPrintingService.create_and_process_batch([])
        
        expect(result).to be false
      end

      it 'does not enqueue any jobs' do
        BatchPrintingService.create_and_process_batch([])
        
        expect(Resque).not_to have_received(:enqueue)
      end
    end
  end

  describe '.check_batch_status' do
    let(:batch_id) { 'test_batch_123' }
    let(:mock_response) { double('response', success?: true, body: '{"status": "complete", "printed_count": 5}') }

    before do
      allow(PrintBatchJob).to receive(:send).with(:tktprint_request, :get, "print_batches/#{batch_id}").and_return(mock_response)
    end

    context 'with successful response' do
      it 'returns parsed JSON response' do
        result = BatchPrintingService.check_batch_status(batch_id)
        
        expect(result).to eq({ 'status' => 'complete', 'printed_count' => 5 })
      end
    end

    context 'with failed response' do
      let(:mock_response) { double('response', success?: false, body: 'Service unavailable') }

      it 'returns error message' do
        result = BatchPrintingService.check_batch_status(batch_id)
        
        expect(result).to eq({ error: 'Failed to get batch status: Service unavailable' })
      end
    end

    context 'with exception' do
      before do
        allow(PrintBatchJob).to receive(:send).and_raise(StandardError.new('Network error'))
      end

      it 'returns error message' do
        result = BatchPrintingService.check_batch_status(batch_id)
        
        expect(result).to eq({ error: 'Error checking batch status: Network error' })
      end
    end
  end

  describe '.generate_batch_id' do
    it 'generates unique batch IDs' do
      id1 = BatchPrintingService.send(:generate_batch_id)
      id2 = BatchPrintingService.send(:generate_batch_id)
      
      expect(id1).not_to eq(id2)
    end

    it 'follows the expected format' do
      allow(Time).to receive(:current).and_return(Time.parse('2025-01-15 14:30:45'))
      allow(SecureRandom).to receive(:hex).with(4).and_return('abc123de')
      
      batch_id = BatchPrintingService.send(:generate_batch_id)
      
      expect(batch_id).to eq('20250115_143045_abc123de')
    end
  end
end