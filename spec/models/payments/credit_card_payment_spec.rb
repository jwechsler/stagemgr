require 'rails_helper'

RSpec.describe CreditCardPayment, type: :model do
  describe '#refund!' do
    let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :general_admission) }
    let(:payment) do
      CreditCardPayment.create!(
        order: order,
        amount: 50.00,
        payment_type: PaymentType.find_by(display_name: 'Credit Card') || FactoryBot.create(:credit_card_payment_type),
        confirmation_code: 'ch_test123',
        transaction_id: 'ch_test123',
        card_type: 'Visa',
        card_last_four: '4242',
        card_expiration_month: 12,
        card_expiration_year: 2030,
        address: order.address
      )
    end

    before do
      # Set up Stripe API key for tests
      Stripe.api_key = 'sk_test_fake_key_for_testing'
    end

    context 'when charge has already been refunded in Stripe' do
      let(:stripe_charge) do
        double('Stripe::Charge',
               id: 'ch_test123',
               refunded: true,
               amount_refunded: 5000, # $50.00 in cents
               amount: 5000,
               to_hash: { id: 'ch_test123', refunded: true, amount_refunded: 5000 })
      end

      before do
        allow(Stripe::Charge).to receive(:retrieve).with('ch_test123').and_return(stripe_charge)
      end

      it 'reconciles the order when refund amount matches' do
        # Mock the gateway to return "already refunded" error
        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)

        response = double('response', success?: false, message: 'Charge ch_test123 has already been refunded')
        allow(gateway).to receive(:refund).and_return(response)

        # Force payment to be loaded before counting
        payment.reload
        initial_payment_count = order.payments.reload.count

        expect do
          payment.refund!(nil, 'test refund')
        end.not_to raise_error

        order.reload
        # Should have created one refund payment
        expect(order.payments.count).to eq(initial_payment_count + 1)

        refund_payment = order.payments.reload.last
        expect(refund_payment.amount).to eq(-50.00)
      end

      it 'creates a carryover payment when refund amount differs from order amount' do
        # Stripe refunded $45.00 but order was $50.00
        different_stripe_charge = double('Stripe::Charge',
                                         id: 'ch_test123',
                                         refunded: true,
                                         amount_refunded: 4500, # $45.00 in cents
                                         amount: 5000,
                                         to_hash: { id: 'ch_test123', refunded: true, amount_refunded: 4500 })
        allow(Stripe::Charge).to receive(:retrieve).with('ch_test123').and_return(different_stripe_charge)

        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)

        response = double('response', success?: false, message: 'Charge ch_test123 has already been refunded')
        allow(gateway).to receive(:refund).and_return(response)

        # Force payment to be loaded before counting
        payment.reload
        initial_payment_count = order.payments.reload.count

        expect do
          payment.refund!(nil, 'test refund')
        end.not_to raise_error

        order.reload
        # Should have created refund payment + carryover payment
        # initial_payment_count includes the original payment, so +2 for refund and carryover
        expect(order.payments.count).to eq(initial_payment_count + 2)

        # Find the refund and carryover payments (last 2 added)
        new_payments = order.payments.reload.last(2)
        refund_payment = new_payments.find { |p| p.is_a?(CreditCardPayment) && p.amount < 0 }
        carryover_payment = new_payments.find { |p| p.is_a?(PriceOverridePayment) }

        expect(refund_payment.amount).to eq(-45.00)
        expect(carryover_payment.amount).to eq(-5.00) # Difference
      end

      it 'handles payment intent IDs by looking up the charge' do
        payment.update_column(:transaction_id, 'pi_test123')

        payment_intent = double('Stripe::PaymentIntent',
                                charges: double(data: [double(id: 'ch_converted_from_pi')]))
        allow(Stripe::PaymentIntent).to receive(:retrieve).with('pi_test123').and_return(payment_intent)

        converted_charge = double('Stripe::Charge',
                                  id: 'ch_converted_from_pi',
                                  refunded: true,
                                  amount_refunded: 5000,
                                  amount: 5000,
                                  to_hash: { id: 'ch_converted_from_pi', refunded: true, amount_refunded: 5000 })
        allow(Stripe::Charge).to receive(:retrieve).with('ch_converted_from_pi').and_return(converted_charge)

        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)

        response = double('response', success?: false, message: 'Charge pi_test123 has already been refunded')
        allow(gateway).to receive(:refund).and_return(response)

        expect do
          payment.refund!(nil, 'test refund')
        end.not_to raise_error

        order.reload
        refund_payment = order.payments.reload.detect { |p| p.amount < 0 }
        expect(refund_payment.amount).to eq(-50.00)
      end

      it 'assumes full refund if cannot retrieve Stripe refund amount' do
        allow(Stripe::Charge).to receive(:retrieve).and_raise(Stripe::InvalidRequestError.new('Not found', 'charge'))

        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)

        response = double('response', success?: false, message: 'Charge ch_test123 has already been refunded')
        allow(gateway).to receive(:refund).and_return(response)

        # Force payment to be loaded before counting
        payment.reload
        initial_payment_count = order.payments.reload.count

        expect do
          payment.refund!(nil, 'test refund')
        end.not_to raise_error

        order.reload
        # Should have created one refund payment assuming full amount
        expect(order.payments.count).to eq(initial_payment_count + 1)

        refund_payment = order.payments.reload.last
        expect(refund_payment.amount).to eq(-50.00) # Full original amount
      end
    end

    context 'when refund fails for other reasons' do
      it "raises CannotProcessPayment for non-'already refunded' errors" do
        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)

        response = double('response', success?: false, message: 'Insufficient funds')
        allow(gateway).to receive(:refund).and_return(response)

        expect do
          payment.refund!(nil, 'test refund')
        end.to raise_error(CannotProcessPayment, 'Insufficient funds')
      end
    end
  end
end
