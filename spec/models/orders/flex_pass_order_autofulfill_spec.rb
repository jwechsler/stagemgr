require 'rails_helper'

RSpec.describe FlexPassOrder, type: :model do
  include_context 'auto-fulfilling print service'

  before { FactoryBot.create(:flex_pass_payment_type) }

  # A unique ticket class code per offer keeps the :ticket_class factory's
  # unscoped find_or_create_by(class_code:) from colliding with the 'PASS'
  # class the production factory creates (see flex_pass_payment_spec.rb).
  def next_pass_class_code
    @offer_sequence = (@offer_sequence || 0) + 1
    "AFT#{@offer_sequence}"
  end

  # Tomorrow keeps the performances safely in the future (autofulfill rejects
  # past performances); staggering by full 15-minute blocks keeps
  # same-production performances unique after Performance#clean_values rounds
  # times down.
  def future_performance_of(production)
    @performance_offset = (@performance_offset || 0) + 1
    FactoryBot.create(:general_admission, production: production,
                                          performance_date: Date.current + 1,
                                          performance_time: Time.now + (@performance_offset * 15).minutes)
  end

  # Builds a production carrying the pass ticket class, the requested
  # performances (each allocated for that class), and an autofulfilling offer
  # against all of them.
  def autofulfill_setup(performance_count: 2, uses_per_performance: 2, number_of_tickets: 10, **offer_attrs)
    production = FactoryBot.create(:production)
    class_code = next_pass_class_code
    production.ticket_classes << FactoryBot.create(:ticket_class, class_code: class_code,
                                                                  class_name: 'Pass Ticket', ticket_price: 0.00,
                                                                  web_visible: false, software_managed: true,
                                                                  production: production, auto_attach: true)
    performances = Array.new(performance_count) { future_performance_of(production) }
    offer = FactoryBot.create(:flex_pass_offer,
                              use_ticket_class_code: class_code,
                              maximum_uses_per_performance: uses_per_performance,
                              number_of_tickets: number_of_tickets,
                              autofulfill_performance_codes: performances.map(&:performance_code).join(', '),
                              **offer_attrs)
    [offer, performances]
  end

  def purchase(offer)
    order = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)
    order.transition_to!(Order::PROCESSED)
    order
  end

  describe 'a successful autofulfilling purchase' do
    it 'creates a processed ticket order per performance, paid by the new flex pass' do
      offer, performances = autofulfill_setup

      order = nil
      expect { order = purchase(offer) }.to change(TicketOrder, :count).by(2)

      expect(order.reload).to be_processed
      flex_pass = order.flex_pass

      performances.each do |performance|
        ticket_order = TicketOrder.find_by(performance_id: performance.id)
        expect(ticket_order).to be_processed
        expect(ticket_order.number_of_tickets).to eq(2)
        expect(ticket_order.ticket_line_items.map { |tli| tli.ticket_class.class_code }.uniq)
          .to eq([offer.use_ticket_class_code])
        expect(ticket_order.address).to eq(order.address)

        expect(ticket_order.payments.size).to eq(1)
        payment = ticket_order.payments.first
        expect(payment).to be_a(FlexPassPayment)
        expect(payment.flex_pass).to eq(flex_pass)
        expect(payment.number_of_tickets).to eq(2)
      end

      expect(flex_pass.uses_remaining).to eq(offer.number_of_tickets - 4)
    end

    it 'enqueues the normal confirmation tasks on each auto-created order' do
      offer, = autofulfill_setup

      purchase(offer)

      TicketOrder.find_each do |ticket_order|
        expect(ticket_order.tasks.grep(OutreachTask)).not_to be_empty
      end
    end

    it 'fulfills independently for two passes of the same offer' do
      offer, = autofulfill_setup(performance_count: 1)

      first_order = purchase(offer)
      second_order = purchase(offer)

      expect(TicketOrder.count).to eq(2)
      expect(first_order.flex_pass.uses_remaining).to eq(offer.number_of_tickets - 2)
      expect(second_order.flex_pass.uses_remaining).to eq(offer.number_of_tickets - 2)
    end
  end

  describe 'a purchase of an offer without autofulfill codes' do
    it 'creates no ticket orders' do
      offer = FactoryBot.create(:flex_pass_offer)

      expect { purchase(offer) }.not_to change(TicketOrder, :count)
    end
  end

  describe 'a failing autofulfilling purchase' do
    def expect_rolled_back_purchase(offer, error_matcher)
      order = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(StandardError)

      expect(order.errors[:base].join).to match(error_matcher)
      expect(order.errors[:base].join).to include('Could not reserve tickets for')
      expect(TicketOrder.count).to eq(0)
      expect(FlexPassPayment.count).to eq(0)
      expect(order.reload.status).to eq(Order::HOLD)
      expect(order.payments.reload).to be_empty
      order
    end

    it 'rolls back everything when an allocation cannot cover the tickets' do
      offer, performances = autofulfill_setup
      performances.last.allocation(offer.use_ticket_class_code).update!(ticket_limit: 1)

      expect_rolled_back_purchase(offer, /tickets/)
    end

    it 'rolls back everything when a performance has already occurred' do
      offer, performances = autofulfill_setup
      performances.last.update_columns(performance_date: Date.current - 1)

      expect_rolled_back_purchase(offer, /already occurred/)
    end

    it 'rolls back everything when a performance switched to reserved seating' do
      offer, performances = autofulfill_setup
      production = performances.first.production
      production.update!(seat_map: production.venue.seat_maps.first)

      expect_rolled_back_purchase(offer, /reserved seating/)
    end

    it 'rolls back everything when a performance code no longer resolves' do
      offer, performances = autofulfill_setup(performance_count: 1)
      performances.first.update_columns(performance_code: 'MOVED99')

      expect_rolled_back_purchase(offer, /no longer exists/)
    end

    it 'rolls back the auto-created orders when the flex pass payment itself fails' do
      offer, = autofulfill_setup
      order = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)
      allow(order).to receive(:create_proper_payment_in_amount_of!)
        .and_raise(CannotProcessPayment, 'Card declined')

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(CannotProcessPayment)

      expect(TicketOrder.count).to eq(0)
      expect(FlexPassPayment.count).to eq(0)
      expect(order.reload.status).to eq(Order::HOLD)
    end
  end
end
