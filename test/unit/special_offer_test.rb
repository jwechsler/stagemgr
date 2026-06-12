require 'test_helper'

class SpecialOfferTest < ActiveSupport::TestCase
  context 'a one-time special offer for any performance of $2 off a GEN* ticket' do
    setup do
      @special_offer = FactoryBot.create(:amount_off_special_offer, amount: 2, code: 'TEST', ticket_class_code: 'GEN',
                                                                    number_of_uses: 1)
      @order = FactoryBot.create(:ticket_order, performance: performances(:macbeth_opening), special_offer_code: 'TEST',
                                                payment_type: FactoryBot.create(:cash_payment_type))
      @order.ticket_line_items.build(ticket_class: ticket_classes(:macbeth_general_admission), ticket_count: 1)
    end
    should 'match the offer to the order' do
      offer = SpecialOffer.find_by_order(@order)
      assert_not_nil offer
      @order.transition_to!(Order::PROCESSING)
      assert_not_nil(1, @order.special_offer_line_item)
      @order.transition_to!(Order::PROCESSED)
    end

    should 'not allow more than one redemption' do
      @order.transition_to!(Order::PROCESSING)
      @order.transition_to!(Order::PROCESSED)
      second_order = FactoryBot.create(:ticket_order, performance: performances(:macbeth_opening),
                                                      special_offer_code: 'TEST', payment_type: CashPaymentType.first)
      second_order.ticket_line_items.build(ticket_class: ticket_classes(:macbeth_general_admission),
                                           ticket_count: 1)
      assert_raise { second_order.transition_to!(Order::PROCESSING) }
      assert_nil(second_order.special_offer_line_item)
    end
  end
  # Replace this with your real tests.
  test 'will be found for any given order' do
  end
end
