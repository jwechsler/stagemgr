require 'rails_helper'

# Refund rows are attached through ONE side of the Order/Payment association
# (`order.payments <<`), so the order's in-memory payments match the rows
# written whether has_many_inversing is off (today) or on (the Rails 7.2
# default).
RSpec.describe 'Refund payments with and without has_many_inversing' do
  let(:check_type) { FactoryBot.create(:check_payment_type) }

  def check_paid_order
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, payment_type: check_type)
    CheckPayment.create!(order: order, amount: order.total_due, payment_type: check_type)
    order.update!(status: Order::PROCESSED)
    order
  end

  [false, true].each do |inversing|
    context "with has_many_inversing #{inversing ? 'on' : 'off'}" do
      around do |example|
        old = ActiveRecord::Base.has_many_inversing
        ActiveRecord::Base.has_many_inversing = inversing
        example.run
      ensure
        ActiveRecord::Base.has_many_inversing = old
      end

      it 'refunds a cash payment with one refund row, matched in memory' do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash).reload
        cash = order.payments.to_a.first # loaded, as Order#refund! has it

        cash.refund!

        rows = Payment.where(order_id: order.id).to_a
        expect(rows.size).to eq(2)
        expect(rows.map(&:amount)).to eq([cash.amount, -cash.amount])
        expect(order.payments.to_a.size).to eq(rows.size)
        expect(order.total_paid).to eq(0)
      end

      it 'refunds a check payment with one reversal row, matched in memory' do
        order = check_paid_order.reload
        check = order.payments.to_a.first # loaded, as Order#refund! has it

        check.refund!

        reversals = ReversalPayment.where(payment_id: check.id).to_a
        expect(reversals.size).to eq(1)
        expect(reversals.first.amount).to eq(-check.amount)
        expect(reversals.first.order_id).to eq(order.id)
        expect(order.payments.to_a.size).to eq(Payment.where(order_id: order.id).count)
        expect(order.total_paid).to eq(0)
      end
    end
  end
end
