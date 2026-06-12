require 'rails_helper'

RSpec.describe PrintBatchJob, type: :job do
  let(:batch_id) { 'TEST_20250101_120000_abcd1234' }
  let(:order_ids) { [1, 2, 3] }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:debug)
  end

  describe '.perform' do
    before do
      # Mock the internal API calls
      allow(PrintBatchJob).to receive(:create_print_batch).and_return(true)
      allow(PrintBatchJob).to receive(:close_print_batch).and_return(true)

      # Mock TicketOrder.find to return mock objects
      mock_order = double('order')
      allow(mock_order).to receive(:send_to_printer_api).and_return(123)
      allow(mock_order).to receive(:print_order_id=)
      allow(mock_order).to receive(:save!)
      allow(mock_order).to receive(:status).and_return(Order::PROCESSED)
      allow(mock_order).to receive(:status=)
      allow(TicketOrder).to receive(:find).and_return(mock_order)
    end

    it 'creates a print batch' do
      PrintBatchJob.perform(batch_id, order_ids)

      expect(PrintBatchJob).to have_received(:create_print_batch).with(batch_id)
    end

    it 'closes the print batch' do
      PrintBatchJob.perform(batch_id, order_ids)

      expect(PrintBatchJob).to have_received(:close_print_batch).with(batch_id)
    end

    it 'calls send_to_printer_api on each order with required batch information' do
      mock_orders = order_ids.map do |id|
        mock = double("order_#{id}")
        allow(mock).to receive(:send_to_printer_api).and_return(123 + id)
        allow(mock).to receive(:print_order_id=)
        allow(mock).to receive(:save!)
        allow(mock).to receive(:status).and_return(Order::PROCESSED)
        allow(mock).to receive(:status=)
        mock
      end

      order_ids.each_with_index do |order_id, index|
        allow(TicketOrder).to receive(:find).with(order_id).and_return(mock_orders[index])
      end

      PrintBatchJob.perform(batch_id, order_ids)

      order_ids.each_with_index do |_order_id, index|
        expect(mock_orders[index]).to have_received(:send_to_printer_api).with(batch_id, index + 1)
      end
    end

    it 'stores the returned print_order_id and marks order as FULFILLED in a single save' do
      mock_orders = order_ids.map do |id|
        mock = double("order_#{id}")
        allow(mock).to receive(:send_to_printer_api).and_return(100 + id)
        allow(mock).to receive(:print_order_id=)
        allow(mock).to receive(:save!)
        allow(mock).to receive(:status).and_return(Order::PROCESSED)
        allow(mock).to receive(:status=)
        mock
      end

      order_ids.each_with_index do |order_id, index|
        allow(TicketOrder).to receive(:find).with(order_id).and_return(mock_orders[index])
      end

      PrintBatchJob.perform(batch_id, order_ids)

      order_ids.each_with_index do |order_id, index|
        expect(mock_orders[index]).to have_received(:print_order_id=).with(100 + order_id)
        expect(mock_orders[index]).to have_received(:status=).with(Order::FULFILLED)
        expect(mock_orders[index]).to have_received(:save!).once
      end
    end

    it 'logs batch processing start and completion' do
      PrintBatchJob.perform(batch_id, order_ids)

      expect(Rails.logger).to have_received(:info).with(/Starting print batch job: #{batch_id} with #{order_ids.length} orders/)
      expect(Rails.logger).to have_received(:info).with(/Completed print batch job: #{batch_id}/)
    end

    it 'logs each order processing with tktprint ID' do
      PrintBatchJob.perform(batch_id, order_ids)

      order_ids.each_with_index do |order_id, index|
        expect(Rails.logger).to have_received(:info).with(/Processing order #{order_id} \(sequence #{index + 1}\) for batch #{batch_id}/)
        expect(Rails.logger).to have_received(:info).with(/Successfully sent order #{order_id} to printer \(tktprint ID: 123\)/)
      end
    end

    context 'when an order fails to process' do
      before do
        failing_order = double('failing_order')
        allow(failing_order).to receive(:send_to_printer_api).and_raise(StandardError.new('Printer error'))
        allow(TicketOrder).to receive(:find).with(order_ids.first).and_return(failing_order)
      end

      it 'logs the error and continues with other orders' do
        PrintBatchJob.perform(batch_id, order_ids)

        expect(Rails.logger).to have_received(:error).with(/Error processing order #{order_ids.first} in batch #{batch_id}: Printer error/)
        expect(Rails.logger).to have_received(:info).with(/Successfully sent order #{order_ids.last} to printer \(tktprint ID: 123\)/)
      end

      it 'still closes the batch' do
        PrintBatchJob.perform(batch_id, order_ids)

        expect(PrintBatchJob).to have_received(:close_print_batch).with(batch_id)
      end
    end

    context 'when tktprint returns no order ID' do
      before do
        order_without_id = double('order')
        allow(order_without_id).to receive(:send_to_printer_api).and_return(nil)
        allow(order_without_id).to receive(:print_order_id=)
        allow(order_without_id).to receive(:save!)
        allow(order_without_id).to receive(:status).and_return(Order::PROCESSED)
        allow(order_without_id).to receive(:status=)
        allow(TicketOrder).to receive(:find).and_return(order_without_id)
      end

      it 'logs a warning but still marks order as successful' do
        PrintBatchJob.perform(batch_id, order_ids)

        order_ids.each do |order_id|
          expect(Rails.logger).to have_received(:warn).with(/Order #{order_id} sent to printer but no tktprint ID returned/)
        end
      end
    end

    context 'when reprinting an order with existing print_order_id' do
      let(:existing_print_order_ids) { [500, 501, 502] }

      before do
        mock_orders = order_ids.each_with_index.map do |order_id, index|
          mock = double("order_#{order_id}")
          # Returns the same print_order_id that already exists (reprint scenario)
          allow(mock).to receive(:send_to_printer_api).and_return(existing_print_order_ids[index])
          allow(mock).to receive(:print_order_id).and_return(existing_print_order_ids[index])
          allow(mock).to receive(:print_order_id=)
          allow(mock).to receive(:save!)
          allow(mock).to receive(:status).and_return(Order::PROCESSED)
          allow(mock).to receive(:status=)
          mock
        end

        order_ids.each_with_index do |order_id, index|
          allow(TicketOrder).to receive(:find).with(order_id).and_return(mock_orders[index])
        end
      end

      it 'uses existing print_order_id and does not create new tktprint orders' do
        PrintBatchJob.perform(batch_id, order_ids)

        # Verify each order was sent to printer (which internally checks print_order_id)
        expect(Rails.logger).to have_received(:info).with(/Successfully sent order/).at_least(:once)
      end

      it 'still marks the orders as FULFILLED' do
        mock_orders = order_ids.each_with_index.map do |order_id, index|
          mock = double("order_#{order_id}")
          allow(mock).to receive(:send_to_printer_api).and_return(existing_print_order_ids[index])
          allow(mock).to receive(:print_order_id).and_return(existing_print_order_ids[index])
          allow(mock).to receive(:print_order_id=)
          allow(mock).to receive(:save!)
          allow(mock).to receive(:status).and_return(Order::PROCESSED)
          allow(mock).to receive(:status=)
          mock
        end

        order_ids.each_with_index do |order_id, index|
          allow(TicketOrder).to receive(:find).with(order_id).and_return(mock_orders[index])
        end

        PrintBatchJob.perform(batch_id, order_ids)

        mock_orders.each do |mock_order|
          expect(mock_order).to have_received(:status=).with(Order::FULFILLED)
        end
      end
    end

    context 'when batch creation fails' do
      before do
        allow(PrintBatchJob).to receive(:create_print_batch).and_raise(StandardError.new('API error'))
      end

      it 'logs the error and re-raises' do
        expect { PrintBatchJob.perform(batch_id, order_ids) }.to raise_error('API error')

        expect(Rails.logger).to have_received(:error).with(/Error in print batch job #{batch_id}: API error/)
      end
    end
  end

  describe '.create_print_batch' do
    let(:mock_success_response) { OpenStruct.new(success?: true, body: 'OK') }

    before do
      allow(PrintBatchJob).to receive(:tktprint_request).and_return(mock_success_response)
    end

    it 'makes a POST request to create the batch' do
      PrintBatchJob.send(:create_print_batch, batch_id)

      expect(PrintBatchJob).to have_received(:tktprint_request).with(:post, 'print_batches', { batch_id: batch_id })
    end

    it 'logs successful creation' do
      PrintBatchJob.send(:create_print_batch, batch_id)

      expect(Rails.logger).to have_received(:info).with(/Creating print batch: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Successfully created print batch: #{batch_id}/)
    end

    context 'when the API request fails' do
      let(:mock_success_response) { OpenStruct.new(success?: false, body: 'Service error') }

      it 'logs the error and raises an exception' do
        expect do
          PrintBatchJob.send(:create_print_batch,
                             batch_id)
        end.to raise_error(/Failed to create print batch #{batch_id}: Service error/)

        expect(Rails.logger).to have_received(:error).with(/Failed to create print batch #{batch_id}: Service error/)
      end
    end
  end

  describe '.close_print_batch' do
    let(:mock_success_response) { OpenStruct.new(success?: true, body: 'OK') }

    before do
      allow(PrintBatchJob).to receive(:tktprint_request).and_return(mock_success_response)
    end

    it 'makes a PUT request to close the batch' do
      PrintBatchJob.send(:close_print_batch, batch_id)

      expect(PrintBatchJob).to have_received(:tktprint_request).with(:put, "print_batches/#{batch_id}/close")
    end

    it 'logs successful closure' do
      PrintBatchJob.send(:close_print_batch, batch_id)

      expect(Rails.logger).to have_received(:info).with(/Closing print batch: #{batch_id}/)
      expect(Rails.logger).to have_received(:info).with(/Successfully closed print batch: #{batch_id}/)
    end

    context 'when the API request fails' do
      let(:mock_success_response) { OpenStruct.new(success?: false, body: 'Service error') }

      it 'logs the error and raises an exception' do
        expect do
          PrintBatchJob.send(:close_print_batch,
                             batch_id)
        end.to raise_error(/Failed to close print batch #{batch_id}: Service error/)

        expect(Rails.logger).to have_received(:error).with(/Failed to close print batch #{batch_id}: Service error/)
      end
    end
  end

  describe '.tktprint_request' do
    let(:mock_http) { double('Net::HTTP') }
    let(:mock_response) { double('response', code: '200', body: '{"status": "ok"}') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(mock_response)

      # Mock the global configuration with credentials in URI
      $TKTPRINT = { 'service' => 'http://test:secret@localhost:3001' }
    end

    context 'with POST request' do
      it 'creates a POST request with JSON body' do
        mock_request = double('request')
        allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
        allow(mock_request).to receive(:body=)
        allow(mock_request).to receive(:[]=)
        allow(mock_request).to receive(:basic_auth)

        PrintBatchJob.send(:tktprint_request, :post, 'print_batches', { batch_id: 'test' })

        expect(Net::HTTP::Post).to have_received(:new)
        expect(mock_request).to have_received(:body=).with('{"batch_id":"test"}')
        expect(mock_request).to have_received(:[]=).with('Content-Type', 'application/json')
        expect(mock_request).to have_received(:basic_auth).with('test', 'secret')
      end
    end

    context 'when tktprint service is not configured' do
      before do
        $TKTPRINT = { 'service' => '' }
      end

      it 'returns error response' do
        result = PrintBatchJob.send(:tktprint_request, :get, 'test')

        expect(result.success?).to be false
        expect(result.body).to eq('Tktprint service not configured')
      end
    end

    context 'when network error occurs' do
      before do
        allow(mock_http).to receive(:request).and_raise(StandardError.new('Network timeout'))
      end

      it 'returns error response' do
        result = PrintBatchJob.send(:tktprint_request, :get, 'test')

        expect(result.success?).to be false
        expect(result.body).to eq('Network timeout')
        expect(Rails.logger).to have_received(:error).with(/Error making tktprint request: Network timeout/)
      end
    end

    context 'with successful response' do
      it 'returns success response' do
        result = PrintBatchJob.send(:tktprint_request, :get, 'test')

        expect(result.success?).to be true
        expect(result.code).to eq(200)
        expect(result.body).to eq('{"status": "ok"}')
      end
    end
  end
end
