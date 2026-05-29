require 'rails_helper'

RSpec.describe PrintingService, type: :service do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_single_ticket) }
  let(:orders) { FactoryBot.create_list(:ticket_order, 3, :for_a_single_ticket) }
  let(:order_ids) { orders.map(&:id) }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '.print_order' do
    it 'creates a batch with single order' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      batch_id = PrintingService.print_order(order.id)
      
      expect(batch_id).to match(/^INDIVIDUAL_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'accepts batch_type parameter' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      batch_id = PrintingService.print_order(order.id, batch_type: :reprint)
      
      expect(batch_id).to match(/^REPRINT_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'logs the batch creation' do
      allow(Resque).to receive(:enqueue)
      
      PrintingService.print_order(order.id)
      
      expect(Rails.logger).to have_received(:info).with(/PrintingService: Creating individual batch .* for 1 orders/)
    end

    it 'returns the generated batch_id' do
      allow(Resque).to receive(:enqueue)
      
      batch_id = PrintingService.print_order(order.id)
      
      expect(batch_id).to be_a(String)
      expect(batch_id).not_to be_empty
    end
  end

  describe '.print_orders' do
    it 'creates a batch with multiple orders' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), order_ids)
      
      batch_id = PrintingService.print_orders(order_ids)
      
      expect(batch_id).to match(/^INDIVIDUAL_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'accepts batch_type parameter' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), order_ids)
      
      batch_id = PrintingService.print_orders(order_ids, batch_type: :bulk)
      
      expect(batch_id).to match(/^BULK_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'handles single order in array' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      batch_id = PrintingService.print_orders([order.id])
      
      expect(batch_id).to match(/^INDIVIDUAL_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'handles integer order_id by converting to array' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      batch_id = PrintingService.print_orders(order.id)
      
      expect(batch_id).to match(/^INDIVIDUAL_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'logs the batch creation with correct count' do
      allow(Resque).to receive(:enqueue)
      
      PrintingService.print_orders(order_ids)
      
      expect(Rails.logger).to have_received(:info).with(/PrintingService: Creating individual batch .* for 3 orders/)
    end
  end

  describe '.reprint_order' do
    it 'creates a reprint batch' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      batch_id = PrintingService.reprint_order(order.id)
      
      expect(batch_id).to match(/^REPRINT_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'is equivalent to print_order with reprint batch_type' do
      expect(PrintingService).to receive(:print_order).with(order.id, batch_type: :reprint)
      
      PrintingService.reprint_order(order.id)
    end
  end

  describe '.generate_batch_id' do
    it 'generates unique batch IDs' do
      batch_id1 = PrintingService.send(:generate_batch_id, :individual)
      batch_id2 = PrintingService.send(:generate_batch_id, :individual)
      
      expect(batch_id1).not_to eq(batch_id2)
    end

    it 'includes batch type prefix' do
      batch_id = PrintingService.send(:generate_batch_id, :test)
      
      expect(batch_id).to start_with('TEST_')
    end

    it 'includes timestamp' do
      batch_id = PrintingService.send(:generate_batch_id, :individual)
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      
      expect(batch_id).to include(timestamp)
    end

    it 'includes random suffix' do
      batch_id = PrintingService.send(:generate_batch_id, :individual)
      
      expect(batch_id).to match(/^INDIVIDUAL_\d{8}_\d{6}_[a-f0-9]{8}$/)
    end

    it 'generates different suffixes for same timestamp' do
      allow(Time).to receive(:current).and_return(Time.parse('2025-01-01 12:00:00'))
      
      batch_id1 = PrintingService.send(:generate_batch_id, :individual)
      batch_id2 = PrintingService.send(:generate_batch_id, :individual)
      
      expect(batch_id1).not_to eq(batch_id2)
      expect(batch_id1).to start_with('INDIVIDUAL_20250101_120000_')
      expect(batch_id2).to start_with('INDIVIDUAL_20250101_120000_')
    end
  end

  describe 'batch type variations' do
    it 'supports individual batch type' do
      batch_id = PrintingService.send(:generate_batch_id, :individual)
      expect(batch_id).to start_with('INDIVIDUAL_')
    end

    it 'supports reprint batch type' do
      batch_id = PrintingService.send(:generate_batch_id, :reprint)
      expect(batch_id).to start_with('REPRINT_')
    end

    it 'supports bulk batch type' do
      batch_id = PrintingService.send(:generate_batch_id, :bulk)
      expect(batch_id).to start_with('BULK_')
    end

    it 'supports legacy batch type' do
      batch_id = PrintingService.send(:generate_batch_id, :legacy)
      expect(batch_id).to start_with('LEGACY_')
    end
  end

  describe 'error handling' do
    it 'handles empty order array' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [])
      
      PrintingService.print_orders([])
    end

    it 'handles nil order_ids' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [])
      
      PrintingService.print_orders(nil)
    end
  end

  describe 'integration with existing job system' do
    it 'enqueues PrintBatchJob with correct parameters' do
      expect(Resque).to receive(:enqueue).with(PrintBatchJob, kind_of(String), [order.id])
      
      PrintingService.print_order(order.id)
    end

    it 'generates batch_id in expected format for job consumption' do
      allow(Resque).to receive(:enqueue) do |job_class, *args|
        next unless job_class == PrintBatchJob
        batch_id, order_ids = args
        expect(batch_id).to be_a(String)
        expect(batch_id).not_to be_empty
        expect(order_ids).to eq([order.id])
      end

      PrintingService.print_order(order.id)
    end
  end
end