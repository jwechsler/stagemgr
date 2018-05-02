FactoryBot.define do

  trait :order do
    status Order::ORDER_STATUSES.first
    association :address, :factory => :address
    association :payment_type, :factory=>:cash_payment_type
  end


  factory :ticket_order do
    order
    association :performance, :factory => :performance

    trait :paid_with_credit_card do

      association :payment_type, :factory=>:credit_card_payment_type
      after(:create) do |ticket_order, evaluator|
        num_tix = TicketLineItem.sum(:ticket_count, :conditions=>['id = ?', ticket_order.id])
        ticket_order.payments << FactoryBot.create(:credit_card_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>(num_tix * ticket_order.ticket_line_items.inject(0){ |total, tli| total += tli.ticket_class.ticket_price }),
                            :transaction_id => 'TEST_TRANSACTION',
                            :confirmation_code => 'CONFIRMED',
                            :card_type=>'Visa',
                            :card_last_four=>'1111')
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :for_a_pair_of_tickets do

      after(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
      end

    end

    trait :for_an_expensive_pair_of_tickets do
      after(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.sort{|tca1, tca2| tca2.ticket_class.ticket_price <=> tca1.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
    end

    end

    trait :paid_with_flex_pass do
      transient do
        flex_pass_code 'TESTPASS'
      end
      association :payment_type, :factory=>:flex_pass_payment_type
      after(:create) do |ticket_order, evaluator|
        find_code = FlexPass.find_by_code(evaluator.flex_pass_code).flex_pass_offer.use_ticket_class_code
        new_ticket_class = ticket_order.performance.ticket_class_allocations.select {|tca|
          tca.ticket_class.class_code == find_code }.first.ticket_class
        TicketLineItem.find_all_by_order_id(ticket_order.id).each do |tli|
          tli.ticket_class = new_ticket_class
          tli.save!
        end
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        ticket_order.payments << FactoryBot.create(:flex_pass_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :flex_pass_id => FlexPass.find_by_code(evaluator.flex_pass_code).id,
                            :amount=>(num_tix * new_ticket_class.ticket_price))
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :paid_with_cash do

      association :payment_type, :factory=>:cash_payment_type
      after(:create) do |ticket_order, evaluator|
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        ticket_order.payments << FactoryBot.create(:cash_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>(num_tix * ticket_order.ticket_line_items.inject(0){ |total, tli| total += tli.ticket_class.ticket_price }))
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end



    factory :ticket_order_for_a_pair_of_tickets_paid_with_flexpass, :traits=>[:for_a_pair_of_tickets, :paid_with_flex_pass]
    factory :ticket_order_for_a_pair_of_tickets_paid_with_cash, :traits=>[:for_a_pair_of_tickets, :paid_with_cash]
    factory :ticket_order_for_a_pair_of_tickets, :traits=>[:for_a_pair_of_tickets]
    factory :ticket_order_for_an_expensive_pair_of_tickets, :traits=>[:for_an_expensive_pair_of_tickets]
    factory :ticket_order_for_a_pair_of_tickets_paid_with_credit_card, :traits=>[:for_a_pair_of_tickets, :paid_with_credit_card]
  end

  factory :membership_order do
    order
    association :payment_type, :factory=>:credit_card_payment_type
    after(:create) do |membership_order, evaluator|
      membership = FactoryBot.create(:membership, :address=>membership_order.address)
      membership_order.membership_line_items << FactoryBot.create(:membership_line_item, :order=>membership_order, :address=>membership_order.address, :membership=>membership)
      membership_order.payments << FactoryBot.build(:credit_card_payment,
                          :amount=>membership_order.membership_line_items.first.membership_offer.recurring_cost,
                          :transaction_id => 'TEST_TRANSACTION',
                          :confirmation_code => 'CONFIRMED',
                          :card_type=>'Visa',
                          :card_last_four=>'1111')
      membership_order.status = Order::PROCESSED
      membership_order.save!
    end
  end

  trait :one_thousand_dollar_donation do
    association :payment_type, :factory=>:credit_card_payment_type
      after(:create) do |donation_order, evaluator|
        donation_order.donation_line_items << FactoryBot.create(:donation_line_item, :donation_amount=>1000.00)
        donation_order.save!
      end
  end

  factory :donation_order do
    order

    factory :donation_order_for_one_thousand_dollars, :traits=>[:one_thousand_dollar_donation]

  end

   factory :donation_pledge_order do
      order


      trait :paid_with_credit_card do
        credit_card_type 'Visa'
        credit_card_number  '4111111111111111'
        credit_card_expiration_month '12'
        credit_card_expiration_year Date.today.year.to_s
        credit_card_verification_number '999'
        after(:create) do |order, evaluator|
          order.create_proper_payment_in_amount_of!(order.value_of_all_line_items)
        end

      end

      factory :donation_pledge_order_for_one_thousand_dollars, :traits=>[:one_thousand_dollar_donation]
      factory :donation_pledge_order_for_one_thousand_dollars_using_credit_card, :traits=>[:one_thousand_dollar_donation, :paid_with_credit_card]
    end


end
