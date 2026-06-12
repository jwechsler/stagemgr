require 'rails_helper'

RSpec.describe TicketOrder, '#send_to_printer_api with hide_pricing' do
  before do
    # Mock tktprint service configuration
    $TKTPRINT = { 'service' => 'http://test:secret@localhost:3001' }

    # Mock the HTTP request to tktprint
    allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api).and_return(123)
  end

  context 'with mixed ticket classes (some hide_pricing, some not)' do
    let(:ticket_order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

    before do
      # Create a second ticket class with hide_pricing=true
      hidden_tc = FactoryBot.create(:ticket_class,
                                    production: ticket_order.performance.production,
                                    class_code: 'COMP',
                                    ticket_price: 10.00,
                                    hide_pricing: true)
      FactoryBot.create(:ticket_class_allocation,
                        performance: ticket_order.performance,
                        ticket_class: hidden_tc,
                        ticket_limit: 10)

      # Add a hidden pricing ticket to the order
      ticket_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
                                                          ticket_class: hidden_tc,
                                                          ticket_count: 1,
                                                          order: ticket_order)

      # Set the first ticket class to have hide_pricing=false explicitly
      ticket_order.ticket_line_items.first.ticket_class.update!(hide_pricing: false)
      ticket_order.reload
    end

    it 'sends $0 for line items with hide_pricing=true' do
      # Capture the payload sent to tktprint
      captured_payload = nil
      allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api) do |_instance, payload|
        captured_payload = payload
        123
      end

      ticket_order.send_to_printer_api('TEST_BATCH', 1)

      expect(captured_payload).not_to be_nil

      # Check line items
      line_items = captured_payload[:line_items_attributes]
      expect(line_items.length).to eq(2)

      # Find the line items by checking which has hide_pricing
      visible_tli = ticket_order.ticket_line_items.find { |tli| !tli.ticket_class.hide_pricing }
      hidden_tli = ticket_order.ticket_line_items.find { |tli| tli.ticket_class.hide_pricing }

      visible_line_item = line_items.find { |li| li[:description].include?(visible_tli.ticket_class.class_code) }
      hidden_line_item = line_items.find { |li| li[:description].include?(hidden_tli.ticket_class.class_code) }

      # Visible line item should have actual price
      expect(visible_line_item[:amount]).to be > 0

      # Hidden line item should have $0
      expect(hidden_line_item[:amount]).to eq(0)
    end

    it 'calculates order total excluding hide_pricing line items' do
      captured_payload = nil
      allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api) do |_instance, payload|
        captured_payload = payload
        123
      end

      ticket_order.send_to_printer_api('TEST_BATCH', 1)

      # Calculate expected visible amount (only line items without hide_pricing)
      expected_visible_amount = 0
      ticket_order.ticket_line_items.each do |tli|
        expected_visible_amount += tli.receipt_total unless tli.ticket_class.hide_pricing
      end

      # Order amount should only include the visible tickets
      expect(captured_payload[:amount]).to eq(expected_visible_amount)
    end

    it 'includes all tickets in tickets_attributes regardless of hide_pricing' do
      captured_payload = nil
      allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api) do |_instance, payload|
        captured_payload = payload
        123
      end

      ticket_order.send_to_printer_api('TEST_BATCH', 1)

      # Should have 3 tickets total (2 from factory + 1 hidden)
      tickets = captured_payload[:tickets_attributes]
      expect(tickets.length).to eq(3)

      # Verify we have tickets from both ticket classes
      ticket_classes_in_payload = tickets.map { |t| t[:ticket_class] }.uniq
      expect(ticket_classes_in_payload.length).to eq(2)
    end
  end

  context 'with all tickets having hide_pricing=true' do
    let(:ticket_order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

    before do
      # Set all ticket classes to have hide_pricing=true
      ticket_order.ticket_line_items.each do |tli|
        tli.ticket_class.update!(hide_pricing: true)
      end
      ticket_order.reload
    end

    it 'sends $0 for all line items and $0 total' do
      captured_payload = nil
      allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api) do |_instance, payload|
        captured_payload = payload
        123
      end

      ticket_order.send_to_printer_api('TEST_BATCH', 1)

      # All line items should be $0
      line_items = captured_payload[:line_items_attributes]
      line_items.each do |li|
        expect(li[:amount]).to eq(0)
      end

      # Order total should be $0
      expect(captured_payload[:amount]).to eq(0)
    end
  end

  context 'with no tickets having hide_pricing=true' do
    let(:ticket_order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

    before do
      # Set all ticket classes to have hide_pricing=false explicitly
      ticket_order.ticket_line_items.each do |tli|
        tli.ticket_class.update!(hide_pricing: false)
      end
      ticket_order.reload
    end

    it 'sends actual amounts for all line items' do
      captured_payload = nil
      allow_any_instance_of(TicketOrder).to receive(:send_order_to_tktprint_api) do |_instance, payload|
        captured_payload = payload
        123
      end

      ticket_order.send_to_printer_api('TEST_BATCH', 1)

      # All line items should have actual prices
      line_items = captured_payload[:line_items_attributes]
      actual_total = ticket_order.total_paid

      line_items.each do |li|
        expect(li[:amount]).to be > 0 # Should have actual positive amounts
      end

      # Order total should be actual total
      expect(captured_payload[:amount]).to eq(actual_total)
    end
  end
end
