require 'rails_helper'

# The review flag on an order and its one-click fixes, after a refund made in
# the Stripe dashboard (StripeRefundRecorder) left the order out of balance.
RSpec.describe ReviewFlaggable do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:card) { order.payments.grep(CreditCardPayment).first }
  let(:user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:gateway) { PaymentProcessing::BogusGateway.new }

  before do
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:refund).and_call_original
  end

  def refund_in_stripe(amount)
    RefundPayment.create!(order: order, source_payment: card, payment_type: card.payment_type,
                          amount: -amount, stripe_refund_id: "re_#{SecureRandom.hex(4)}",
                          note: StripeRefundRecorder::NOTE)
    order.flag_for_review!("Stripe refund $#{format('%.2f', amount)}")
    order.reload
  end

  describe 'the flag' do
    it 'is listed as needing review until it is resolved' do
      order.flag_for_review!('Stripe refund $20.00 on 10/02')

      expect(Order.needing_review).to include(order)
      expect(order.reload).to have_attributes(needs_review?: true, review_reason: 'Stripe refund $20.00 on 10/02')
      expect(order.audits.last.comment).to eq('Flagged for review: Stripe refund $20.00 on 10/02')
    end

    it 'adds a second reason to an order already waiting' do
      order.flag_for_review!('Stripe refund $20.00 on 10/02')
      order.flag_for_review!('Stripe refund $5.00 on 10/03')

      expect(order.reload.review_reason).to eq('Stripe refund $20.00 on 10/02; Stripe refund $5.00 on 10/03')
    end

    it 'reopens a reviewed order with only the new reason' do
      order.flag_for_review!('first')
      order.resolve_review!(user, 'done')
      order.flag_for_review!('second')

      expect(order.reload).to have_attributes(needs_review?: true, review_reason: 'second', reviewed_by_id: nil)
    end

    it 'leaves the status and tickets alone' do
      expect { order.flag_for_review!('Stripe refund') }
        .not_to(change { [order.reload.status, order.ticket_line_items.count, order.total_due] })
    end
  end

  describe '#resolve_review!' do
    it 'records who resolved it and their note' do
      order.flag_for_review!('Stripe refund $20.00')

      order.resolve_review!(user, 'Patron agreed to a partial refund')

      order.reload
      expect(order).not_to be_needs_review
      expect(order).to have_attributes(reviewed_by: user, review_note: 'Patron agreed to a partial refund')
      expect(order.reviewed_at).to be_within(1.minute).of(Time.current)
      expect(order.audits.last).to have_attributes(user_id: user.id,
                                                   comment: 'Review resolved: Patron agreed to a partial refund')
      expect(Order.needing_review).not_to include(order)
    end
  end

  describe '#balance_difference' do
    it 'is what a dashboard refund took from a balanced order' do
      refund_in_stripe(5)

      expect(order.balance_difference).to eq(5)
      expect(order.review_due_total - order.review_paid_total).to eq(5)
    end
  end

  describe '#apply_review_discount!' do
    it 'keeps the tickets and brings what is due down to what was paid' do
      refund_in_stripe(5)

      order.apply_review_discount!(user, '')

      order.reload
      expect(order.total_due).to eq(order.total_paid)
      expect(order.adjustment_line_items.map(&:amount)).to eq([-5])
      expect(order.adjustment_line_items.first.description).to eq('Stripe refund adjustment')
      expect(order.ticket_line_items.sum(:ticket_count)).to eq(2)
      expect(order).not_to be_needs_review
      expect(order.review_note).to eq('Kept tickets; applied the refund as a discount.')
    end

    it 'refuses a second discount once the order balances' do
      refund_in_stripe(5)
      order.apply_review_discount!(user, '')
      order.flag_for_review!('again')

      expect { order.reload.apply_review_discount!(user, '') }.to raise_error(ReviewFlaggable::ReviewFixNotAllowed)
      expect(order.adjustment_line_items.count).to eq(1)
    end
  end

  describe '#mark_review_refunded!' do
    it 'is offered only once the card is refunded in full in Stripe' do
      refund_in_stripe(5)

      expect(order.review_refund_available?).to be(false)
      expect { order.mark_review_refunded!(user, '') }.to raise_error(ReviewFlaggable::ReviewFixNotAllowed)
    end

    it 'refunds the order without a second card refund' do
      refund_in_stripe(card.amount)
      expect(order.review_refund_available?).to be(true)

      order.mark_review_refunded!(user, 'Refunded in Stripe by the manager')

      order.reload
      expect(gateway).not_to have_received(:refund)
      expect(order.status).to eq(Order::REFUNDED)
      expect(order.total_paid).to eq(0)
      expect(order).not_to be_needs_review
      expect(order.review_note).to eq('Refunded in Stripe by the manager')
    end
  end
end
