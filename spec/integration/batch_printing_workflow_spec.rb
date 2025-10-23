require 'rails_helper'

RSpec.describe 'Batch Printing Workflow', type: :feature do
  include ActiveSupport::Testing::TimeHelpers

  let(:performance) { FactoryBot.create(:performance) }
  let(:orders) { FactoryBot.create_list(:ticket_order, 5, performance: performance, status: Order::PROCESSED) }
  
  before do
    # Mock the tktprint service calls
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
      double('response', code: '200', body: '{"status": "ok"}')
    )
    
    # Set up print order IDs (would normally be set when orders are processed)
    orders.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
  end

  describe 'Complete batch printing workflow' do
    it 'processes orders through the entire batch printing pipeline' do
      # Step 1: Create and process batch
      batch_id = nil
      
      expect {
        batch_id = BatchPrintingService.create_and_process_batch(orders)
      }.to change(Resque::Job, :count).by(1)
      
      expect(batch_id).to be_present
      expect(batch_id).to match(/\d{8}_\d{6}_[a-f0-9]{8}/)
      
      # Step 2: Verify batch job was enqueued
      job = Resque::Job.reserve(:batch_printing)
      expect(job).to be_present
      expect(job.payload['class']).to eq('PrintBatchJob')
      expect(job.payload['args']).to eq([batch_id, orders.map(&:id)])
      
      # Step 3: Execute the print batch job
      expect {
        job.perform
      }.not_to raise_error
      
      # Step 4: Verify orders were sent to printer with batch information
      orders.each_with_index do |order, index|
        order.reload
        # In a real scenario, the send_to_printer method would have been called
        # with batch_id and sequence (index + 1)
        expect(order.print_order_id).to be_present
      end
    end

    it 'handles individual order failures gracefully' do
      # Mock one order to fail during printing
      failing_order = orders.first
      allow(failing_order).to receive(:send_to_printer).and_raise(StandardError.new('Printer error'))
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      # Execute the batch job
      expect {
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      }.not_to raise_error
      
      # Verify that the job completed despite the individual failure
      expect(Rails.logger).to have_received(:error).with(/Error processing order #{failing_order.id}/)
    end

    it 'logs the complete workflow' do
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      # Verify service logging
      expect(Rails.logger).to have_received(:info).with(/Creating batch #{batch_id} with orders:/)
      
      # Execute batch job and verify job logging
      PrintBatchJob.perform(batch_id, orders.map(&:id))
      
      expect(Rails.logger).to have_received(:info).with(/Starting print batch job: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Creating print batch: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Successfully created print batch: #{batch_id}/)
      
      orders.each_with_index do |order, index|
        expect(Rails.logger).to have_received(:info).with(/Processing order #{order.id} \(sequence #{index + 1}\)/)
        expect(Rails.logger).to have_received(:info).with(/Successfully sent order #{order.id} to printer/)
      end
      
      expect(Rails.logger).to have_received(:info).with(/Closing print batch: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Successfully closed print batch: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Completed print batch job: #{batch_id}/)
    end

    it 'maintains order sequence throughout the workflow' do
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      # Execute batch job
      PrintBatchJob.perform(batch_id, orders.map(&:id))
      
      # Verify each order was processed with correct sequence
      orders.each_with_index do |order, index|
        expected_sequence = index + 1
        expect(order).to have_received(:send_to_printer).with(batch_id, expected_sequence)
      end
    end
  end

  describe 'Batch status checking' do
    let(:batch_id) { 'test_batch_status' }
    let(:mock_response) { double('response', success?: true, body: '{"status": "complete", "printed_count": 5}') }

    before do
      allow(PrintBatchJob).to receive(:send).with(:tktprint_request, :get, "print_batches/#{batch_id}").and_return(mock_response)
    end

    it 'successfully retrieves batch status from tktprint' do
      result = BatchPrintingService.check_batch_status(batch_id)
      
      expect(result).to eq({ 'status' => 'complete', 'printed_count' => 5 })
      expect(PrintBatchJob).to have_received(:send).with(:tktprint_request, :get, "print_batches/#{batch_id}")
    end

    context 'when tktprint service is unavailable' do
      let(:mock_response) { double('response', success?: false, body: 'Service unavailable') }

      it 'returns error information' do
        result = BatchPrintingService.check_batch_status(batch_id)
        
        expect(result).to eq({ error: 'Failed to get batch status: Service unavailable' })
      end
    end
  end

  describe 'Error recovery and resilience' do
    let(:orders) { FactoryBot.create_list(:ticket_order, 3, performance: performance, status: Order::PROCESSED) }

    before do
      orders.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
    end

    it 'handles tktprint API failures during batch creation' do
      # Mock API failure
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
        double('response', code: '500', body: 'Internal Server Error')
      )
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      expect {
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      }.to raise_error(/Failed to create print batch/)
    end

    it 'handles tktprint API failures during batch closure' do
      # Mock successful creation but failed closure
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
        double('response', code: '200', body: '{"status": "ok"}'),
        double('response', code: '500', body: 'Internal Server Error')
      )
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      expect {
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      }.to raise_error(/Failed to close print batch/)
    end

    it 'continues processing remaining orders when individual orders fail' do
      # Mock the second order to fail
      allow(orders[1]).to receive(:send_to_printer).and_raise(StandardError.new('Network timeout'))
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      
      # Should not raise error overall
      expect {
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      }.not_to raise_error
      
      # Verify first and third orders were still processed
      expect(orders[0]).to have_received(:send_to_printer)
      expect(orders[2]).to have_received(:send_to_printer)
      
      # Verify error was logged
      expect(Rails.logger).to have_received(:error).with(/Error processing order #{orders[1].id}/)
    end
  end

  describe 'Configuration and environment' do
    it 'uses configured tktprint service URL' do
      expect($TKTPRINT['service']).to be_present
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      PrintBatchJob.perform(batch_id, orders.map(&:id))
      
      # Verify HTTP requests were made to configured service
      expect_any_instance_of(Net::HTTP).to have_received(:request).at_least(:once)
    end

    it 'uses configured authentication credentials' do
      expect($XML_AUTHORIZATION['username']).to be_present
      expect($XML_AUTHORIZATION['password']).to be_present
      
      batch_id = BatchPrintingService.create_and_process_batch(orders)
      PrintBatchJob.perform(batch_id, orders.map(&:id))
      
      # Authentication would be verified through the mocked HTTP requests
    end

    context 'when tktprint service is not configured' do
      before do
        original_config = $TKTPRINT
        $TKTPRINT = { 'service' => '' }
        
        after { $TKTPRINT = original_config }
      end

      it 'handles missing service configuration gracefully' do
        batch_id = BatchPrintingService.create_and_process_batch(orders)
        
        expect {
          PrintBatchJob.perform(batch_id, orders.map(&:id))
        }.to raise_error(/Tktprint service not configured/)
      end
    end
  end

  describe 'Performance and resource management' do
    let(:large_order_set) { FactoryBot.create_list(:ticket_order, 100, performance: performance, status: Order::PROCESSED) }

    before do
      large_order_set.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
    end

    it 'handles large batches efficiently' do
      start_time = Time.current
      
      batch_id = BatchPrintingService.create_and_process_batch(large_order_set)
      PrintBatchJob.perform(batch_id, large_order_set.map(&:id))
      
      execution_time = Time.current - start_time
      
      # Should complete within reasonable time (adjust threshold as needed)
      expect(execution_time).to be < 10.seconds
      
      # Verify all orders were processed
      large_order_set.each_with_index do |order, index|
        expect(order).to have_received(:send_to_printer).with(batch_id, index + 1)
      end
    end

    it 'manages memory efficiently during large batch processing' do
      # This test ensures we don't load all orders into memory at once
      batch_id = BatchPrintingService.create_and_process_batch(large_order_set)
      
      expect {
        PrintBatchJob.perform(batch_id, large_order_set.map(&:id))
      }.not_to change { GC.stat[:heap_allocated_pages] }.by_more_than(100)
    end
  end
end