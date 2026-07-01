require 'rails_helper'

RSpec.describe 'an flexpass ticket order' do
  context 'when placed for two tickets' do
    before do
      @original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_flex_pass)
      @flex_pass = @original_order.payments.first.flex_pass
      @flex_pass_offer = @flex_pass.flex_pass_offer
      expect(@flex_pass_offer.number_of_tickets).to eq(10)
    end

    it 'should reflect the correct initial number of tickets on flex_pass_offer' do
      expect(@flex_pass_offer.number_of_tickets).to eq(10)
    end

    it 'should reduce the number of tickets remaining on flex_pass by two' do
      expect(@flex_pass.uses_remaining).to eq(@flex_pass_offer.number_of_tickets - 2)
    end

    it 'should return the flex_pass tickets when refunded' do
      expect(@original_order.payments.count).to eq(1)
      @original_order.refund!
      expect(@original_order.payments.count).to eq(2)
      expect(@flex_pass.uses_remaining).to eq(@flex_pass_offer.number_of_tickets)
    end
  end
end
