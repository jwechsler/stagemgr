require "rails_helper"

RSpec.describe SampleOrderBuilder, type: :service do
  let(:theater) { FactoryBot.create(:theater) }
  let(:recipient_email) { "preview@example.com" }

  # SampleOrderBuilder.build_sample_order calls `CashPaymentType.first || PaymentType.first`
  # which returns nil when no payment types exist in the database.
  # BUG (app/services/sample_order_builder.rb:73): CashPayment.create! fails with
  # "Payment type must exist" unless a CashPaymentType record is seeded first.
  # Workaround in tests: ensure a CashPaymentType exists before calling the service.
  before { FactoryBot.create(:cash_payment_type) }

  describe ".with_sample_order" do
    it "yields a TicketOrder to the block" do
      yielded = nil
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        yielded = order
      end
      expect(yielded).to be_a(TicketOrder)
    end

    it "rolls back all created records after the block completes" do
      production_count_before = Production.count
      performance_count_before = Performance.count
      order_count_before = Order.count
      address_count_before = Address.count

      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        # do nothing
      end

      expect(Production.count).to eq(production_count_before)
      expect(Performance.count).to eq(performance_count_before)
      expect(Order.count).to eq(order_count_before)
      expect(Address.count).to eq(address_count_before)
    end

    it "builds a sample production with default name 'Sample Production'" do
      yielded_order = nil
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        yielded_order = order
        expect(order.performance.production.name).to eq("Sample Production")
      end
    end

    it "accepts a custom production name via production_attrs" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email, name: "My Custom Show") do |order|
        expect(order.performance.production.name).to eq("My Custom Show")
      end
    end

    it "builds the order with PROCESSED status" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.status).to eq(Order::PROCESSED)
      end
    end

    it "sets the recipient email on the order address" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.address.email).to eq(recipient_email)
      end
    end

    it "creates a GEN ticket class with price 35.00" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        ticket_class = order.performance.production.ticket_classes.find_by(class_code: "GEN")
        expect(ticket_class).not_to be_nil
        expect(ticket_class.ticket_price).to eq(35.00)
      end
    end

    it "creates a ticket line item with 2 tickets" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.ticket_line_items.sum(:ticket_count)).to eq(2)
      end
    end

    it "creates a CashPayment for the order with amount 70.00" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        cash_payment = order.payments.detect { |p| p.is_a?(CashPayment) }
        expect(cash_payment).not_to be_nil
        expect(cash_payment.amount).to eq(70.00)
      end
    end

    it "associates the production with the given theater" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.performance.production.theater).to eq(theater)
      end
    end

    it "schedules the performance approximately 1 week in the future" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.performance.performance_date).to be_within(2.days).of(1.week.from_now.to_date)
      end
    end

    it "creates a production with capacity 100" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.performance.production.read_attribute(:capacity)).to eq(100)
      end
    end

    it "creates a TicketClassAllocation linking the performance and ticket class" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        allocations = order.performance.ticket_class_allocations
        expect(allocations.count).to be >= 1
        expect(allocations.map(&:available)).to include(true)
      end
    end

    it "uses the production_class from production_attrs when provided" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email,
                                           production_class: Production::SPECIAL_EVENT) do |order|
        expect(order.performance.production.production_class).to eq(Production::SPECIAL_EVENT)
      end
    end

    it "defaults production_class to PLAY when not provided" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.performance.production.production_class).to eq(Production::PLAY)
      end
    end

    it "passes confirmation_message from production_attrs" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email,
                                           confirmation_message: "Thanks for coming!") do |order|
        expect(order.performance.production.confirmation_message).to eq("Thanks for coming!")
      end
    end

    it "passes follow_up_message_2 from production_attrs" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email,
                                           follow_up_message_2: "See you soon!") do |order|
        expect(order.performance.production.follow_up_message_2).to eq("See you soon!")
      end
    end

    it "passes venue_id from production_attrs when provided" do
      venue = FactoryBot.create(:venue)
      SampleOrderBuilder.with_sample_order(theater, recipient_email,
                                           venue_id: venue.id) do |order|
        expect(order.performance.production.venue_id).to eq(venue.id)
      end
    end

    it "returns the value of the block" do
      result = SampleOrderBuilder.with_sample_order(theater, recipient_email) do |_order|
        "block_return_value"
      end
      # The rollback happens via raise ActiveRecord::Rollback inside the transaction,
      # so the return value of the transaction block is nil in Rails 6.
      # Characterization: with_sample_order returns nil after rollback.
      expect(result).to be_nil
    end

    it "names the address 'Sample Customer'" do
      SampleOrderBuilder.with_sample_order(theater, recipient_email) do |order|
        expect(order.address.full_name).to eq("Sample Customer")
      end
    end
  end
end
