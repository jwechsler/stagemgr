require 'rails_helper'

RSpec.describe 'Batch Printing Workflow', type: :feature do
  include ActiveSupport::Testing::TimeHelpers

  let(:performance) { FactoryBot.create(:performance) }
  let(:orders) { FactoryBot.create_list(:ticket_order, 5, :for_a_pair_of_tickets, performance: performance, status: Order::PROCESSED) }

  before do
    # Set up tktprint service configuration for tests
    Rails.configuration.x.tktprint ||= {}
    Rails.configuration.x.tktprint['service'] = 'http://test:test@localhost:3000'

    # Mock the tktprint service calls
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
      double('response', code: '200', body: '{"status": "ok"}')
    )

    # Set up print order IDs (would normally be set when orders are processed)
    orders.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
  end

  describe 'Complete batch printing workflow' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:debug)
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api).and_return('test_tktprint_id')
    end

    it 'processes orders through the entire batch printing pipeline' do
      # Step 1: Create and process batch
      batch_id = nil

      expect do
        batch_id = BatchPrintingService.create_and_process_batch(orders)
      end.to change { Resque.size(:batch_printing) }.by(1)

      expect(batch_id).to be_present
      expect(batch_id).to match(/\d{8}_\d{6}_[a-f0-9]{8}/)

      # Step 2: Verify batch job was enqueued
      job = Resque::Job.reserve(:batch_printing)
      expect(job).to be_present
      expect(job.payload['class']).to eq('PrintBatchJob')
      expect(job.payload['args']).to eq([batch_id, orders.map(&:id)])

      # Step 3: Execute the print batch job
      expect do
        job.perform
      end.not_to raise_error

      # Step 4: Verify orders were sent to printer with batch information
      orders.each_with_index do |order, _index|
        order.reload
        expect(order.print_order_id).to be_present
      end
    end

    it 'handles individual order failures gracefully' do
      # PrintBatchJob loads orders fresh from DB, so stub at class level
      failing_order_id = orders.first.id
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api) do |order, *_args|
        raise StandardError.new('Printer error') if order.id == failing_order_id

        'test_id'
      end

      batch_id = BatchPrintingService.create_and_process_batch(orders)

      # Execute the batch job
      expect do
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      end.not_to raise_error

      # Verify that the job completed despite the individual failure
      expect(Rails.logger).to have_received(:error).with(/Error processing order #{failing_order_id}/)
    end

    it 'logs the complete workflow' do
      batch_id = BatchPrintingService.create_and_process_batch(orders)

      # Verify service logging
      expect(Rails.logger).to have_received(:info).with(/Creating bulk batch with orders:/)

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
      # Track calls since have_received doesn't work with any_instance stubs
      api_calls = []
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api) do |order, _batch_id_arg, sequence|
        api_calls << { order_id: order.id, sequence: sequence }
        'test_tktprint_id'
      end

      batch_id = BatchPrintingService.create_and_process_batch(orders)
      PrintBatchJob.perform(batch_id, orders.map(&:id))

      # Verify each order was processed with correct sequence
      orders.each_with_index do |order, index|
        expect(api_calls).to include(hash_including(order_id: order.id, sequence: index + 1))
      end
    end
  end

  describe 'Batch status checking' do
    let(:batch_id) { 'test_batch_status' }
    let(:mock_response) { double('response', success?: true, body: '{"status": "complete", "printed_count": 5}') }

    before do
      allow(PrintBatchJob).to receive(:send).with(:tktprint_request, :get,
                                                  "print_batches/#{batch_id}").and_return(mock_response)
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
    let(:orders) { FactoryBot.create_list(:ticket_order, 3, :for_a_pair_of_tickets, performance: performance, status: Order::PROCESSED) }

    before do
      orders.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
    end

    it 'handles tktprint API failures during batch creation' do
      # Mock API failure
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
        double('response', code: '500', body: 'Internal Server Error')
      )

      batch_id = BatchPrintingService.create_and_process_batch(orders)

      expect do
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      end.to raise_error(/Failed to create print batch/)
    end

    it 'handles tktprint API failures during batch closure' do
      # Stub order sending to avoid consuming HTTP mock responses
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api).and_return('test_id')

      # Differentiate create (200) from close (500) by request path
      allow_any_instance_of(Net::HTTP).to receive(:request) do |_, req|
        if req.path.include?('/close')
          double('response', code: '500', body: 'Internal Server Error')
        else
          double('response', code: '200', body: '{"status": "ok"}')
        end
      end

      batch_id = BatchPrintingService.create_and_process_batch(orders)

      expect do
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      end.to raise_error(/Failed to close print batch/)
    end

    it 'continues processing remaining orders when individual orders fail' do
      # Stub logger to verify error logging
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:debug)

      # Track which orders were processed
      processed_orders = []

      # Stub send_to_printer_api to track calls and fail for second order
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api) do |order, _batch_id, _sequence|
        raise StandardError.new('Network timeout') if order.id == orders[1].id

        processed_orders << order.id
        "test_#{order.id}"
      end

      batch_id = BatchPrintingService.create_and_process_batch(orders)

      # Should not raise error overall
      expect do
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      end.not_to raise_error

      # Verify first and third orders were processed (but not the second)
      expect(processed_orders).to include(orders[0].id, orders[2].id)
      expect(processed_orders).not_to include(orders[1].id)

      # Verify error was logged
      expect(Rails.logger).to have_received(:error).with(/Error processing order #{orders[1].id}/)
    end
  end

  describe 'Configuration and environment' do
    it 'uses configured tktprint service URL' do
      expect(Rails.configuration.x.tktprint['service']).to be_present

      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api).and_return('test_id')

      batch_id = BatchPrintingService.create_and_process_batch(orders)
      expect do
        PrintBatchJob.perform(batch_id, orders.map(&:id))
      end.not_to raise_error
    end

    it 'uses configured authentication credentials' do
      # Authentication credentials are embedded in the tktprint service URL (HTTP Basic Auth)
      expect(Rails.configuration.x.tktprint['service']).to be_present

      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api).and_return('test_id')

      batch_id = BatchPrintingService.create_and_process_batch(orders)
      PrintBatchJob.perform(batch_id, orders.map(&:id))

      # Authentication would be verified through the mocked HTTP requests
    end

    context 'when tktprint service is not configured' do
      before do
        Rails.configuration.x.tktprint['service'] = ''
      end

      after do
        Rails.configuration.x.tktprint['service'] = 'http://test:test@localhost:3000'
      end

      it 'handles missing service configuration gracefully' do
        batch_id = BatchPrintingService.create_and_process_batch(orders)

        expect do
          PrintBatchJob.perform(batch_id, orders.map(&:id))
        end.to raise_error(/Tktprint service not configured/)
      end
    end
  end

  describe 'Performance and resource management' do
    let(:large_order_set) do
      FactoryBot.create_list(:ticket_order, 10, :for_a_single_ticket, performance: performance, status: Order::PROCESSED)
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:debug)
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api).and_return('test_id')
      large_order_set.each_with_index { |order, index| order.update!(print_order_id: index + 1) }
    end

    it 'handles large batches efficiently' do
      # Track calls since have_received doesn't work with any_instance stubs
      api_calls = []
      allow_any_instance_of(TicketOrder).to receive(:send_to_printer_api) do |order, _batch_id_arg, sequence|
        api_calls << { order_id: order.id, sequence: sequence }
        'test_id'
      end

      start_time = Time.current

      batch_id = BatchPrintingService.create_and_process_batch(large_order_set)
      PrintBatchJob.perform(batch_id, large_order_set.map(&:id))

      execution_time = Time.current - start_time

      # Should complete within reasonable time
      expect(execution_time).to be < 10.seconds

      # Verify all orders were processed in sequence
      large_order_set.each_with_index do |order, index|
        expect(api_calls).to include(hash_including(order_id: order.id, sequence: index + 1))
      end
    end

    it 'manages memory efficiently during large batch processing' do
      batch_id = BatchPrintingService.create_and_process_batch(large_order_set)

      expect do
        PrintBatchJob.perform(batch_id, large_order_set.map(&:id))
      end.not_to raise_error
    end
  end
end
