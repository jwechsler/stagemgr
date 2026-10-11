require 'rails_helper'

# Order#transition_processing_to_processed! runs every check that can fail
# before the gateway charge, so a failed check never leaves a card charged for
# an order that rolled back.
RSpec.describe 'Charging only after every check' do
  let(:gateway) { double('gateway') }
  let(:approved) { double('response', success?: true, authorization: 'ch_test', params: {}, message: 'Approved') }
  let(:declined) { double('response', success?: false, authorization: nil, params: {}, message: 'card_declined') }
  let(:card_type) { FactoryBot.create(:credit_card_payment_type) }

  before do
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:purchase).and_return(approved)
  end

  def with_card(order)
    order.credit_card_number = '4111111111111111'
    order.credit_card_type = 'bogus'
    order.credit_card_expiration_month = '12'
    order.credit_card_expiration_year = (Date.current.year + 1).to_s
    order.credit_card_verification_number = '999'
    order
  end

  def card_order(*traits)
    with_card(FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, *traits, payment_type: card_type))
  end

  def expect_no_charge_and_unprocessed(order, error = /unsuccessful/)
    expect { order.transition_to!(Order::PROCESSED) }.to raise_error(error)
    expect(gateway).not_to have_received(:purchase)
    expect(order).not_to be_processed
    expect(CreditCardPayment.count).to eq(0)
  end

  describe 'the happy path' do
    it 'charges exactly once and persists the processed order with its payment' do
      order = card_order
      due = order.total_due

      order.transition_to!(Order::PROCESSED)

      expect(gateway).to have_received(:purchase).once.with((due * 100).to_i, anything, anything)
      order.reload
      expect(order).to be_processed
      expect(order.payments.map(&:class)).to eq([CreditCardPayment])
      expect(order.payments.first.confirmation_code).to eq('ch_test')
      expect(order.total_paid).to eq(due)
    end
  end

  describe 'a declined card' do
    it 'raises the decline and leaves no order or payment behind, as before' do
      allow(gateway).to receive(:purchase).and_return(declined)
      order = card_order

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(CannotProcessPayment, 'card_declined')

      expect(gateway).to have_received(:purchase).once
      expect(order.status).to eq(Order::NEW)
      expect(order.id).to be_nil
      expect(CreditCardPayment.count).to eq(0)
    end
  end

  describe 'no gateway call when a check fails' do
    it 'for a payment type restricted for the performance' do
      order = card_order
      order.performance.restricted_payment_types << card_type

      expect_no_charge_and_unprocessed(order)
      expect(order.errors.full_messages).to include('Payment type is not allowed for this event')
    end

    it 'for an order with no tickets' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :with_twenty_dollar_service_item,
                                payment_type: card_type)
      order.transition_to!(Order::PROCESSING)
      order.ticket_line_items.first.update_columns(ticket_count: 0)
      order.ticket_line_items.reload
      # Isolate the PROCESSED-only ticket check from the seat/ticket-count check.
      allow(order).to receive(:seat_assignments_complete?).and_return(true)

      expect_no_charge_and_unprocessed(with_card(order))
      expect(order.errors.full_messages).to include('Ticket line items must contain at least one ticket.')
    end

    it 'for a payment that does not cover the total' do
      order = card_order
      allow(order).to receive(:total).and_return(BigDecimal('1.00'))

      expect_no_charge_and_unprocessed(order)
      expect(order.errors[:status].first).to match(/isn't countered by a payment/)
    end

    it 'for an invalid payment' do
      order = card_order
      allow(card_type).to receive(:build_uncharged_payment).and_wrap_original do |original, *args|
        original.call(*args).tap { |payment| allow(payment).to receive(:valid?).and_return(false) }
      end

      expect_no_charge_and_unprocessed(order, ActiveRecord::RecordInvalid)
      expect(order.payments).to be_empty
    end

    it 'for an invalid additional donation' do
      order = card_order
      order.additional_donation = '-5'

      expect_no_charge_and_unprocessed(order, ActiveRecord::RecordInvalid)
      expect(DonationOrder.count).to eq(0)
    end

    context 'with reserved seats' do
      let(:order) { card_order(:reserved_seating) }

      before { order.seats.update_all(status: SeatAssignment::TEMPORARY) }

      it 'charges when every seat is still held' do
        order.transition_to!(Order::PROCESSED)

        expect(gateway).to have_received(:purchase).once
        expect(order.seats.reload.map(&:status).uniq).to eq([SeatAssignment::ASSIGNED])
      end

      it 'when a seat hold has been released' do
        order.transition_to!(Order::PROCESSING)
        order.seats.first.update_columns(status: SeatAssignment::AVAILABLE, order_uuid: nil)

        expect_no_charge_and_unprocessed(order)
      end

      it 'when a seat on the order is BROKEN' do
        order.seats.first.update_columns(status: SeatAssignment::BROKEN)

        expect_no_charge_and_unprocessed(order)
        expect(order.errors.full_messages)
          .to include('Seats are no longer held for this order. Please select your seats again.')
      end

      it 'when a seat on the order is RELEASING' do
        order.seats.first.update_columns(status: SeatAssignment::RELEASING)

        expect_no_charge_and_unprocessed(order)
        expect(order.errors.full_messages)
          .to include('Seats are no longer held for this order. Please select your seats again.')
      end
    end
  end

  describe 'the balance check' do
    it 'does not block re-saving an order that is already PROCESSED' do
      order = card_order
      order.transition_to!(Order::PROCESSED)
      order.reload
      allow(order).to receive(:total_due).and_return(order.total_paid + 5)

      order.notes = 'Box office note'
      expect(order.save).to be(true)
      expect(order.reload.notes).to eq('Box office note')
    end
  end

  describe 'additional donation orders' do
    it 'charges the donation separately, after the ticket order' do
      order = card_order
      due = order.total_due
      order.additional_donation = '25'

      order.transition_to!(Order::PROCESSED)

      expect(gateway).to have_received(:purchase).with((due * 100).to_i, anything, anything).ordered
      expect(gateway).to have_received(:purchase).with(2500, anything, anything).ordered
      expect(order.reload).to be_processed
      expect(DonationOrder.count).to eq(1)
      donation = DonationOrder.first
      expect(donation).to be_processed
      expect(donation.total_paid).to eq(25)
      expect(order.additional_donation_failures).to be_empty
    end

    context 'when the donation charge is declined after the ticket charge' do
      let(:order) { card_order.tap { |o| o.additional_donation = '25' } }

      before { allow(gateway).to receive(:purchase).and_return(approved, declined) }

      it 'keeps the paid ticket order and leaves no donation behind' do
        order.transition_to!(Order::PROCESSED)

        expect(gateway).to have_received(:purchase).twice
        expect(order.reload).to be_processed
        expect(order.payments.map(&:class)).to eq([CreditCardPayment])
        expect(DonationOrder.count).to eq(0)
        expect(CreditCardPayment.count).to eq(1)
        expect(order.additional_donation_failures)
          .to eq([{ amount: 25, theater: Theater.default_theater.name, reason: 'card_declined' }])
      end

      it 'emails the box office the failure once the order commits, and writes no note' do
        expect { order.transition_to!(Order::PROCESSED) }.to change { ActionMailer::Base.deliveries.count }.by(1)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([Rails.configuration.x.email_address['box_office']])
        expect(mail.subject).to include("Order #{order.id}")
        expect(mail.body.encoded).to include('$25.00').and include('card_declined')
        expect(mail.body.encoded).not_to include('4111')
        expect(order.reload.notes).to be_blank
        expect(NotificationTask.where(order: order)).to be_empty
      end

      it 'does not report a decline to the developers' do
        allow(ExceptionNotifier).to receive(:notify_exception)

        order.transition_to!(Order::PROCESSED)

        expect(ExceptionNotifier).not_to have_received(:notify_exception)
      end

      it 'sends no alert when the ticket order then rolls back' do
        allow(gateway).to receive(:refund).and_return(double('refund', success?: true, message: 'Refunded'))
        allow(order).to receive(:process_additional_donation_orders).and_wrap_original do |original, *args|
          original.call(*args)
          raise ActiveRecord::StatementInvalid, 'lost connection'
        end

        expect { order.transition_to!(Order::PROCESSED) }.to raise_error(ActiveRecord::StatementInvalid)
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it 'keeps the paid order when the alert cannot be sent, and reports the mail failure' do
        allow(ExceptionNotifier).to receive(:notify_exception)
        allow(NotificationMailer).to receive(:additional_donation_failed_alert).and_raise(Net::SMTPFatalError, 'nope')

        expect { order.transition_to!(Order::PROCESSED) }.not_to raise_error

        expect(order.reload).to be_processed
        expect(ExceptionNotifier).to have_received(:notify_exception)
          .with(an_instance_of(Net::SMTPFatalError), data: { order_id: order.id })
      end
    end

    context 'when the donation fails unexpectedly' do
      let(:order) { card_order.tap { |o| o.additional_donation = '25' } }

      before do
        allow(ExceptionNotifier).to receive(:notify_exception)
        allow_any_instance_of(DonationOrder).to receive(:transition_to!)
          .and_raise(NoMethodError, 'undefined method `oops\' for #<DonationOrder id: nil, notes: nil>')
      end

      it 'reports the error to the developers and keeps the paid ticket order' do
        order.transition_to!(Order::PROCESSED)

        expect(order.reload).to be_processed
        expect(ExceptionNotifier).to have_received(:notify_exception).with(
          an_instance_of(NoMethodError),
          data: { donation_amount: 25, theater: Theater.default_theater.name, order_id: order.id }
        )
      end

      it 'tells the box office without the raw error or an order dump' do
        order.transition_to!(Order::PROCESSED)

        body = ActionMailer::Base.deliveries.last.body.encoded
        expect(body).to include(ChargeAfterChecks::UNEXPECTED_DONATION_ERROR_REASON)
        expect(body).not_to include('DonationOrder')
        expect(body).not_to include('oops')
      end
    end

    it 'redacts anything shaped like a card number from the reason' do
      order = card_order
      order.additional_donation = '25'
      card_error = double('response', success?: false, authorization: nil, params: {},
                                      message: 'Card 4111 1111 1111 1111 declined')
      allow(gateway).to receive(:purchase).and_return(approved, card_error)

      order.transition_to!(Order::PROCESSED)

      expect(order.additional_donation_failures.first[:reason]).to eq('Card [redacted] declined')
      expect(ActionMailer::Base.deliveries.last.body.encoded).not_to include('4111')
    end
  end

  describe 'an additional donation on a pass-paid order' do
    before { card_type }

    def with_pass_ticket_class(order, class_code)
      pass_class = FactoryBot.create(:ticket_class, class_code: class_code, class_name: 'Pass Ticket', ticket_price: 0,
                                                    web_visible: false, software_managed: true,
                                                    production: order.performance.production)
      order.performance.ticket_class_allocations << FactoryBot.build(:ticket_class_allocation,
                                                                     available: true, ticket_class: pass_class)
      order
    end

    def membership_paid_order
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                payment_type: FactoryBot.create(:membership_payment_type))
      membership = FactoryBot.create(:membership, address: order.address)
      order.member_code = membership.member_code
      with_pass_ticket_class(order, membership.membership_offer.use_ticket_class_code)
    end

    def flex_pass_paid_order
      # An offer with no theater, so the pass is good for any production.
      flex_pass = FactoryBot.create(:flex_pass_order, flex_pass_offer: FactoryBot.create(:flex_pass_offer)).flex_pass
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                payment_type: FactoryBot.create(:flex_pass_payment_type))
      order.flex_pass_code = flex_pass.code
      with_pass_ticket_class(order, flex_pass.flex_pass_offer.use_ticket_class_code)
    end

    shared_examples 'a pass that covers only the tickets' do |pass_payment_class|
      it 'redeems the pass for the tickets and charges the donation to the card' do
        order = with_card(paid_order)
        order.additional_donation = '25'

        order.transition_to!(Order::PROCESSED)

        expect(gateway).to have_received(:purchase).once.with(2500, anything, anything)
        expect(order.reload).to be_processed
        expect(order.payments.map(&:class)).to eq([pass_payment_class])
        expect(DonationOrder.count).to eq(1)
        donation = DonationOrder.first
        expect(donation).to be_processed
        expect(donation.payment_type).to be_a(CreditCardPaymentType)
        expect(donation.payments.map(&:class)).to eq([CreditCardPayment])
        expect(donation.total_paid).to eq(25)
        expect(order.additional_donation_failures).to be_empty
        expect(order.notes).to be_blank
      end

      it 'asks for a card at Review Order, before the pass is redeemed' do
        order = paid_order
        order.additional_donation = '25'

        expect { order.transition_to!(Order::PROCESSING) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(order.errors[:base]).to include('Please enter a card for your donation.')
      end

      it 'refuses to redeem the pass when no card was entered' do
        order = paid_order
        order.additional_donation = '25'

        expect { order.transition_to!(Order::PROCESSED) }.to raise_error(StandardError)

        expect(order.errors[:base]).to include('Please enter a card for your donation.')
        expect(pass_payment_class.count).to eq(0)
        expect(gateway).not_to have_received(:purchase)
        expect(DonationOrder.count).to eq(0)
      end

      it 'needs no card when there is no donation' do
        order = paid_order

        order.transition_to!(Order::PROCESSED)

        expect(order.reload).to be_processed
        expect(gateway).not_to have_received(:purchase)
      end
    end

    context 'with a membership' do
      let(:paid_order) { membership_paid_order }

      it_behaves_like 'a pass that covers only the tickets', MembershipPayment
    end

    context 'with a flex pass' do
      let(:paid_order) { flex_pass_paid_order }

      it_behaves_like 'a pass that covers only the tickets', FlexPassPayment
    end
  end

  describe 'refunding a charge when a later step fails' do
    let(:refunded) { double('refund', success?: true, message: 'Refunded') }

    before { allow(gateway).to receive(:refund).and_return(refunded) }

    it 'refunds the ticket charge and re-raises, leaving nothing persisted' do
      order = card_order
      due = order.total_due
      allow(order).to receive(:set_email_confirmation).and_raise(ActiveRecord::StatementInvalid, 'lost connection')

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gateway).to have_received(:refund).once.with((due * 100).to_i, 'ch_test', hash_including(:note))
      expect(order).not_to be_processed
      expect(CreditCardPayment.count).to eq(0)
    end

    it 'also refunds an additional donation that went through' do
      order = card_order
      due = order.total_due
      order.additional_donation = '25'
      allow(order).to receive(:process_additional_donation_orders).and_wrap_original do |original, *args|
        original.call(*args)
        raise ActiveRecord::StatementInvalid, 'lost connection'
      end

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gateway).to have_received(:refund).with((due * 100).to_i, 'ch_test', anything)
      expect(gateway).to have_received(:refund).with(2500, 'ch_test', anything)
      expect(DonationOrder.count).to eq(0)
      expect(CreditCardPayment.count).to eq(0)
    end

    it 'does not refund a declined card' do
      allow(gateway).to receive(:purchase).and_return(declined)

      expect { card_order.transition_to!(Order::PROCESSED) }.to raise_error(CannotProcessPayment)

      expect(gateway).not_to have_received(:refund)
    end

    it 'logs a manual refund when the refund itself fails, and still raises the original error' do
      allow(gateway).to receive(:refund).and_return(double('refund', success?: false, message: 'refund_failed'))
      allow(Rails.logger).to receive(:error)
      order = card_order
      allow(order).to receive(:set_email_confirmation).and_raise(ActiveRecord::StatementInvalid, 'lost connection')

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(Rails.logger).to have_received(:error).with(/MANUAL REFUND NEEDED for charge ch_test .*refund_failed/)
    end
  end

  describe 'an exchange that costs more than the original' do
    let(:original) { FactoryBot.create(:ticket_order, :for_a_cheap_pair_of_tickets, :paid_with_cash) }

    def pricier_exchange_for(original)
      pricey_class = FactoryBot.create(:ticket_class, ticket_price: 50.0, class_code: 'PRICY',
                                                      production: original.performance.production)
      performance2 = original.performance.dup
      performance2.performance_date = original.performance.performance_date + 1.day
      performance2.performance_code += 'P'
      performance2.save!
      exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2.reload,
                                                                          payment_type: card_type)
      exchange.ticket_line_items[0].ticket_class = pricey_class
      with_card(exchange)
    end

    it 'charges the difference once, after the checks, and completes the exchange' do
      exchange = pricier_exchange_for(original)
      difference = exchange.total_due - original.total_paid
      expect(difference).to be > 0

      exchange.exchange_and_process_from!(original)

      expect(gateway).to have_received(:purchase).once.with((difference * 100).to_i, anything, anything)
      expect(exchange.reload).to be_processed
      expect(exchange.payments.grep(CreditCardPayment).sum(&:amount)).to eq(difference)
      expect(original.reload.status).to eq(Order::EXCHANGED)
    end

    it 'does not charge when the exchange fails its PROCESSED checks' do
      exchange = pricier_exchange_for(original)
      exchange.performance.restricted_payment_types << card_type

      expect { exchange.exchange_and_process_from!(original) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(gateway).not_to have_received(:purchase)
      expect(original.reload.status).to eq(Order::PROCESSED)
      expect(CreditCardPayment.count).to eq(0)
    end

    it 'refunds the difference when the exchange fails after the charge' do
      allow(gateway).to receive(:refund).and_return(double('refund', success?: true, message: 'Refunded'))
      exchange = pricier_exchange_for(original)
      difference = exchange.total_due - original.total_paid
      allow(exchange).to receive(:charge_proper_payment!).and_wrap_original do |charge, *args|
        charge.call(*args)
        raise ActiveRecord::StatementInvalid, 'lost connection'
      end

      expect { exchange.exchange_and_process_from!(original) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gateway).to have_received(:refund).once.with((difference * 100).to_i, 'ch_test', anything)
      expect(original.reload.status).to eq(Order::PROCESSED)
      expect(CreditCardPayment.count).to eq(0)
    end

    it 'rolls the whole exchange back when the card is declined' do
      allow(gateway).to receive(:purchase).and_return(declined)
      exchange = pricier_exchange_for(original)

      expect { exchange.exchange_and_process_from!(original) }.to raise_error(CannotProcessPayment, 'card_declined')

      expect(original.reload.status).to eq(Order::PROCESSED)
      expect(original.ticket_line_items).not_to be_empty
      expect(CreditCardPayment.count).to eq(0)
    end
  end

  describe 'a membership purchase' do
    let(:address) { FactoryBot.create(:address) }
    let(:order) do
      offer = FactoryBot.create(:membership_offer)
      membership = FactoryBot.create(:membership, address: address, membership_offer: offer)
      order = MembershipOrder.new(address: address, payment_type: card_type, status: Order::NEW)
      order.membership_line_item = FactoryBot.build(:membership_line_item, membership_offer: offer, membership: membership,
                                                                           address: address, order: order)
      with_card(order)
    end

    # Checkout reads an unsynced offer's billing period before charging
    # (MembershipOrder#charge_proper_payment!); this offer's price recurs.
    before do
      allow(gateway).to receive(:price_billing_period).and_return(interval: MembershipOffer::MONTH, interval_count: 1)
    end

    it 'creates the subscription (its charge) once the checks pass' do
      allow(PaymentProcessing).to receive(:create_subscription).and_return('TESTSUBSCRIPTION')

      order.transition_to!(Order::PROCESSED)

      expect(PaymentProcessing).to have_received(:create_subscription).once
      expect(order.reload).to be_processed
      expect(order.membership.profile_id).to eq('TESTSUBSCRIPTION')
    end

    it 'never creates the subscription when a check fails' do
      allow(PaymentProcessing).to receive(:create_subscription)
      order.transition_to!(Order::PROCESSING)
      allow(order.membership).to receive(:valid?).and_return(false)

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(/unsuccessful/)

      expect(PaymentProcessing).not_to have_received(:create_subscription)
    end
  end
end
