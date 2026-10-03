require 'rails_helper'

# Cash and check refunds return only what an exchange-and-refund has not
# already returned against the payment (CurrencyPayment#refundable_amount).
RSpec.describe CurrencyPayment, type: :model do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :general_admission) }

  def partially_refund(payment, amount)
    RefundPayment.create!(order: order, amount: -amount, source_payment: payment, payment_type: payment.payment_type)
  end

  describe CashPayment do
    let(:payment) { CashPayment.create!(order: order, amount: 30, payment_type: FactoryBot.create(:cash_payment_type)) }

    it 'refunds only what is left after an earlier exchange refund' do
      partially_refund(payment, 10)

      payment.refund!

      expect(order.payments.reload.grep(CashPayment).map(&:amount)).to contain_exactly(30, -20)
    end

    it 'has nothing to refund once earlier refunds cover the whole payment' do
      partially_refund(payment, 30)

      expect(payment).not_to be_refundable
    end
  end

  describe CheckPayment do
    let(:check_type) { FactoryBot.create(:check_payment_type).tap { |type| type.update!(report_as_sales_collected: true) } }
    let(:payment) { CheckPayment.create!(order: order, amount: 30, payment_type: check_type) }

    it 'records the refund as a reversal of the check, with the check’s payment type' do
      payment.refund!

      reversal = ReversalPayment.find_by!(payment_id: payment.id)
      expect(reversal.amount).to eq(-30)
      expect(reversal.payment_type).to eq(check_type)
    end

    it 'reverses only what is left after an earlier exchange refund' do
      partially_refund(payment, 12)

      payment.refund!

      expect(ReversalPayment.find_by!(payment_id: payment.id).amount).to eq(-18)
    end
  end
end
