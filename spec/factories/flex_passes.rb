FactoryBot.define do
  factory :flex_pass_offer do
    price                   { 100.0 }
    number_of_tickets       { 10 }
    name                    { 'Flex Pass' }
    use_ticket_class_code   { 'PASS' }
    active                  { true }
    on_sale_to_public       { true }
  end

  factory :flex_pass_order do
    status                  { Order::ORDER_STATUSES.first }
    association             :address, factory: :address
    association             :payment_type, factory: :cash_payment_type

    transient do
      flex_pass_offer { nil }
      skip_line_item { false }
    end

    after(:create) do |flex_pass_order, evaluator|
      unless evaluator.skip_line_item
        offer = evaluator.flex_pass_offer || FactoryBot.create(:flex_pass_offer,
                                                               theater: flex_pass_order.theater || FactoryBot.create(:theater))

        # Create the line item
        flex_pass_line_item = FlexPassLineItem.create!(
          order: flex_pass_order,
          flex_pass_offer: offer,
          ticket_count: 1
        )

        # Create the flex pass
        FlexPass.create!(
          flex_pass_line_item: flex_pass_line_item,
          flex_pass_offer: offer,
          address: flex_pass_order.address,
          code: "TESTPASS#{rand(1000..9999)}",
          expiration_date: Date.today + 12.months,
          active: true
        )

        flex_pass_order.reload
      end
    end

    trait :with_payment do
      after(:create) do |flex_pass_order, _evaluator|
        flex_pass_order.payments << FactoryBot.create(:credit_card_payment,
                                                      order: flex_pass_order,
                                                      amount: flex_pass_order.flex_pass_offer.price,
                                                      transaction_id: 'TEST_TRANSACTION',
                                                      confirmation_code: 'CONFIRMED',
                                                      card_type: 'bogus',
                                                      card_last_four: '1111')
        flex_pass_order.status = Order::PROCESSED
        flex_pass_order.save!
      end
    end
  end

  factory :flex_pass do
    code                    { 'TESTPASS' }
    expiration_date         { Date.today + 12.months }
    association :flex_pass_offer, factory: :flex_pass_offer
    # NOTE: flex_pass_line_item should be set by the creator to avoid circular dependency

    after(:build) do |flex_pass|
      flex_pass.address = flex_pass.order.address if flex_pass.flex_pass_line_item
    end
  end

  factory :flex_pass_line_item do
    association :flex_pass_offer, factory: :flex_pass_offer
    ticket_count { 1 }

    # The order association will be handled by the flex_pass_order factory
  end
end
