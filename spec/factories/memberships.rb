FactoryBot.define do


  factory :membership_offer do
    name                    { 'Test membership' }
    recurring_cost          { BigDecimal.new("5.00") }
    use_ticket_class_code   { 'PASS' }
    tickets_per_performance { 1 }
  end

  factory :membership do
    profile_id      { PaymentProcessing::BogusResponse::PROFILE_ID }
    status          { Membership::ACTIVE }
    membership_offer
  end

  factory :membership_order do
    order
    association :payment_type, :factory=>:credit_card_payment_type
    before(:create) do |membership_order, evaluator|
      membership_offer = FactoryBot.create(:membership_offer)
      membership = FactoryBot.create(:membership, :address=>membership_order.address, membership_offer: membership_offer)
      membership_order.membership_line_item = FactoryBot.create(:membership_line_item, :order=>membership_order, :address=>membership_order.address, membership_offer: membership_offer, :membership=>membership)
      membership_order.payments << FactoryBot.build(:credit_card_payment,
                          :amount=>membership_order.membership.membership_offer.recurring_cost,
                          :transaction_id => 'TEST_TRANSACTION',
                          :confirmation_code => 'CONFIRMED',
                          :card_type=>'Visa',
                          :card_last_four=>'1111')
      membership_order.status = Order::PROCESSED
      membership_order.save!
    end
  end

  factory :membership_line_item do
    association :membership_offer, :factory => :membership_offer
  end

end
