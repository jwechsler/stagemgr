require 'rails_helper'

# charge.refunded for a refund made in the Stripe dashboard: one payment row
# per refund, dated when Stripe made it, and the order flagged for review.
RSpec.describe StripeRefundRecorder do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:card) do
    order.payments.grep(CreditCardPayment).first.tap do |payment|
      payment.update_columns(transaction_id: 'pi_ticket', confirmation_code: 'pi_ticket')
    end
  end
  let(:refunded_at) { 2.days.ago.change(usec: 0) }
  let(:refunds) { [] }

  before do
    card
    allow(Stripe::Refund).to receive(:list).with(hash_including(charge: 'ch_ticket')) do
      Stripe::ListObject.construct_from(data: refunds)
    end
  end

  def charge(**attrs)
    Stripe::Charge.construct_from({ id: 'ch_ticket', object: 'charge', payment_intent: 'pi_ticket',
                                    invoice: nil }.merge(attrs))
  end

  def refund(id, cents, created: refunded_at, status: 'succeeded', metadata: {})
    { id: id, object: 'refund', amount: cents, status: status, created: created.to_i, metadata: metadata }
  end

  def dashboard_refunds
    Payment.where(type: 'RefundPayment', source_payment: card)
  end

  context 'with a partial refund of a ticket order' do
    let(:refunds) { [refund('re_one', 2000)] }

    it 'records one RefundPayment against the card, dated when Stripe refunded it' do
      described_class.call(charge)

      row = dashboard_refunds.first!
      expect(row).to have_attributes(amount: -20.0, stripe_refund_id: 're_one', order_id: order.id,
                                     note: StripeRefundRecorder::NOTE)
      expect(row.processed_on).to eq(refunded_at)
      expect(card.reload.refundable_amount).to eq(card.amount - 20)
    end

    it 'flags the order for review without touching its status or tickets' do
      expect { described_class.call(charge) }.not_to(change { [order.reload.status, order.ticket_line_items.count] })

      order.reload
      expect(order).to be_needs_review
      expect(order.review_reason).to eq("Stripe refund $20.00 on #{refunded_at.to_date.to_formatted_s(:numeric_month_and_day)}")
    end

    it 'records nothing more when the event is delivered again' do
      described_class.call(charge)

      expect { described_class.call(charge) }.not_to(change { dashboard_refunds.count })
    end

    it 'treats a duplicate that wins the race to the unique index as already recorded' do
      described_class.call(charge)
      racing = described_class.new(charge)
      allow(racing).to receive(:already_recorded?).and_return(false)

      expect { racing.call }.not_to raise_error
      expect(dashboard_refunds.count).to eq(1)
    end
  end

  it 'skips a refund the app issued itself' do
    refunds << refund('re_app', 2000, metadata: { source: 'stagemgr', order_id: order.id.to_s })

    described_class.call(charge)

    expect(dashboard_refunds).to be_empty
    expect(order.reload).not_to be_needs_review
  end

  it 'skips a partial refund the app issued before refund ids were stored' do
    RefundPayment.create!(order: order, source_payment: card, payment_type: card.payment_type, amount: -5,
                          transaction_id: 're_exchange', confirmation_code: 're_exchange')
    refunds << refund('re_exchange', 500)

    described_class.call(charge)

    expect(dashboard_refunds.pluck(:amount)).to eq([-5.0])
    expect(order.reload).not_to be_needs_review
  end

  it 'skips a refund that has not succeeded' do
    refunds << refund('re_pending', 2000, status: 'pending')

    described_class.call(charge)

    expect(dashboard_refunds).to be_empty
  end

  it 'books only its own amount for a second partial refund' do
    refunds << refund('re_one', 2000, created: 3.days.ago)
    described_class.call(charge)
    refunds << refund('re_two', 500)

    described_class.call(charge(amount_refunded: 2500))

    expect(dashboard_refunds.order(:id).pluck(:stripe_refund_id, :amount)).to eq([['re_one', -20.0], ['re_two', -5.0]])
    expect(order.reload.review_reason).to include('$20.00').and include('$5.00')
  end

  context 'with a membership invoice charge' do
    let(:membership_order) { FactoryBot.create(:membership_order) }
    let!(:invoice_payment) do
      membership_order.create_recurring_payment!('Subscription Payment', amount: 25.0, invoice_id: 'in_member',
                                                                         processed_on: 40.days.ago)
      membership_order.payments.reload.detect { |payment| payment.is_a?(RecurringPayment) }
    end
    let(:member_charge) { charge(id: 'ch_member', payment_intent: 'pi_member', invoice: 'in_member') }

    before do
      allow(Stripe::Refund).to receive(:list).with(hash_including(charge: 'ch_member'))
                                             .and_return(Stripe::ListObject.construct_from(data: [refund('re_member', 1000)]))
    end

    it 'records a negative RecurringPayment of that refund, dated when Stripe refunded it' do
      described_class.call(member_charge)

      row = Payment.find_by(stripe_refund_id: 're_member')
      expect(row).to be_a(RecurringPayment)
      expect(row).to have_attributes(amount: -10.0, transaction_id: 'in_member', order_id: membership_order.id)
      expect(row.processed_on).to eq(refunded_at)
      expect(membership_order.reload).to be_needs_review
    end

    it 'skips a refund the replaced handler already booked, but books a later one' do
      invoice_payment.build_refund(amount: -10.0, processed_on: refunded_at, note: 'Refund')
                     .tap { |legacy| legacy.update!(created_at: refunded_at + 1.minute) }
      later = refund('re_later', 500, created: refunded_at + 1.day)
      allow(Stripe::Refund).to receive(:list).with(hash_including(charge: 'ch_member'))
                                             .and_return(Stripe::ListObject.construct_from(data: [refund('re_member', 1000), later]))

      described_class.call(member_charge)

      expect(Payment.find_by(stripe_refund_id: 're_member')).to be_nil
      expect(Payment.find_by(stripe_refund_id: 're_later')).to have_attributes(amount: -5.0)
    end

    it 'finds the invoice by re-reading the charge when the event payload has no invoice field' do
      payload = Stripe::Charge.construct_from(id: 'ch_member', object: 'charge', payment_intent: 'pi_member')
      allow(Stripe::Charge).to receive(:retrieve).with('ch_member')
                                                 .and_return(charge(id: 'ch_member', invoice: 'in_member'))

      described_class.call(payload)

      expect(Payment.find_by(stripe_refund_id: 're_member')).to be_a(RecurringPayment)
    end
  end

  it 'logs and notifies an unmatched refund instead of raising' do
    stranger = charge(id: 'ch_stranger', payment_intent: 'pi_stranger')
    allow(Stripe::Refund).to receive(:list).with(hash_including(charge: 'ch_stranger'))
                                           .and_return(Stripe::ListObject.construct_from(data: [refund('re_lost', 700)]))
    allow(Rails.logger).to receive(:error)
    stub_const('ExceptionNotifier', Module.new { def self.notify_exception(*); end })
    allow(ExceptionNotifier).to receive(:notify_exception)

    expect { described_class.call(stranger) }.not_to raise_error

    expect(Rails.logger).to have_received(:error).with(/re_lost.*ch_stranger/)
    expect(ExceptionNotifier).to have_received(:notify_exception)
      .with(an_instance_of(StripeRefundRecorder::UnmatchedRefund),
            data: { charge_id: 'ch_stranger', refund_id: 're_lost' })
    expect(Payment.where(stripe_refund_id: 're_lost')).to be_empty
  end

  it 'flags the last order of an exchange chain while booking the refund on the card it came from' do
    successor = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
    successor.update_columns(exchange_source_id: order.id, status: Order::PROCESSED)
    order.update_columns(status: Order::EXCHANGED)
    refunds << refund('re_chain', 1500)

    described_class.call(charge)

    expect(dashboard_refunds.first!.order_id).to eq(order.id)
    expect(successor.reload).to be_needs_review
    expect(order.reload).not_to be_needs_review
  end
end
