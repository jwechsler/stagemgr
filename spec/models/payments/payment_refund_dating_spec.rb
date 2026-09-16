require 'rails_helper'

# Full refunds duplicate the original tender to build the refund row. Daily
# Receipts buckets payments by processed_on, so the refund must be dated when
# it is issued, not inherit the sale date from the row it was copied from.
RSpec.describe Payment, type: :model do
  describe '#refund!' do
    let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :general_admission) }
    let(:original_processed_on) { 45.days.ago.change(usec: 0) }
    let!(:payment) do
      FactoryBot.create(:cash_payment, order: order, amount: 36.0, processed_on: original_processed_on)
    end

    it 'dates the refund row when it is issued, not when the original was paid' do
      payment.refund!

      refund = order.payments.reload.detect { |p| p.amount.negative? }
      expect(refund.amount).to eq(-36.0)
      expect(refund.processed_on).to be_within(1.minute).of(Time.current)
    end

    it 'leaves the original payment dated as paid' do
      payment.refund!

      expect(payment.reload.processed_on).to be_within(1.second).of(original_processed_on)
    end
  end
end
