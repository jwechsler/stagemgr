FactoryBot.define do
  factory :membership_offer do
    name                    { 'Test membership' }
    use_ticket_class_code   { 'PASS' }
    tickets_per_performance { 2 }
    price_id                { 'TEST' }

    trait :timed do
      membership_type { MembershipOffer::TIMED }
      price_id        { nil }
    end
  end

  factory :membership do
    member_code     { 'TESTMEM' }
    profile_id      { PaymentProcessing::BogusResponse::PROFILE_ID }
    status          { Membership::ACTIVE }
    association     :address
    membership_offer

    factory :library_pass do
      profile_id { nil }
      status     { Membership::ACTIVE }
      association :membership_offer, factory: %i[membership_offer timed]
    end
  end

  factory :membership_order do
    order
    association :payment_type, factory: :credit_card_payment_type
    before(:create) do |membership_order, _evaluator|
      membership_offer = FactoryBot.create(:membership_offer)
      membership = FactoryBot.create(:membership, address: membership_order.address,
                                                  membership_offer: membership_offer)
      membership_order.membership_line_item = FactoryBot.create(:membership_line_item, order: membership_order,
                                                                                       address: membership_order.address, membership_offer: membership_offer, membership: membership)
      membership_order.payments << FactoryBot.build(:credit_card_payment,
                                                    amount: 5.00,
                                                    transaction_id: 'TEST_TRANSACTION',
                                                    confirmation_code: 'CONFIRMED',
                                                    card_type: 'bogus',
                                                    card_last_four: '1111')
      membership_order.status = Order::PROCESSED
      membership_order.save!
    end
  end

  factory :membership_line_item do
    association :membership_offer, factory: :membership_offer
  end
end
