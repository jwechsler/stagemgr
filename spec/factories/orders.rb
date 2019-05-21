FactoryBot.define do

  trait :order do
    status                  { Order::ORDER_STATUSES.first }
    association             :address, :factory => :address
    association             :payment_type, :factory=>:cash_payment_type
  end


  factory :ticket_order do
    order
    performance

    trait :paid_with_credit_card do

      association           :payment_type, :factory=>:credit_card_payment_type
      after(:create) do |ticket_order, evaluator|
        num_tix = TicketLineItem.where(order_id:ticket_order.id).sum(:ticket_count)
        ticket_order.payments << FactoryBot.create(:credit_card_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>(num_tix * ticket_order.ticket_line_items.inject(0){ |total, tli| total += tli.ticket_class.ticket_price }),
                            :transaction_id => 'TEST_TRANSACTION',
                            :confirmation_code => 'CONFIRMED',
                            :card_type=>'bogus',
                            :card_last_four=>'1111')
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :for_a_pair_of_tickets do

      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
      end

    end


    trait :for_an_expensive_pair_of_tickets do
      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.sort{|tca1, tca2| tca2.ticket_class.ticket_price <=> tca1.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
    end

    end

    trait :paid_with_flex_pass do
      transient do
        flex_pass_code      { '' }
      end
      association :payment_type, :factory=>:flex_pass_payment_type
      after(:create) do |ticket_order, evaluator|
        flex_pass = FactoryBot.create(:flex_pass)

        fc_code = evaluator.flex_pass_code.blank? ?  flex_pass.code : evaluator.flex_pass_code
        flex_pass.code = fc_code
        find_code = flex_pass.flex_pass_offer.use_ticket_class_code

        new_ticket_class = ticket_order.performance.ticket_class_allocations.select {|tca|
          tca.ticket_class.class_code == find_code }.first.ticket_class
        TicketLineItem.where(order_id: ticket_order.id).each do |tli|
          tli.ticket_class = new_ticket_class
          tli.save!
        end
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        ticket_order.payments << FactoryBot.create(:flex_pass_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :flex_pass_id => FlexPass.find_by_code(fc_code).id,
                            :amount=>(num_tix * new_ticket_class.ticket_price))
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :paid_with_membership do

      association :payment_type, :factory=>:membership_payment_type

      before(:create) do |ticket_order, evaluator|

      end

      after(:create) do |ticket_order, evaluator|
        membership = FactoryBot.create(:membership, member_code:evaluator.member_code)
        if (ticket_order.performance.production.ticket_classes.select{|tc| tc.class_code.eql?(membership.member_code)}.size == 0)
          ticket_order.performance.production.ticket_classes << FactoryBot.create(:ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>ticket_order.performance.production, :auto_attach=>true)

        end

        ticket_order.member_code=membership.member_code
        find_code = membership.membership_offer.use_ticket_class_code
        new_ticket_class = ticket_order.performance.ticket_class_allocations.select {|tca|
          tca.ticket_class.class_code == find_code }.first.ticket_class
        TicketLineItem.where(order_id: ticket_order.id).each do |tli|
          tli.ticket_class = new_ticket_class
          tli.save!
        end

        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        payment = FactoryBot.create(:membership_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :membership => membership,
                            :amount=>(num_tix * new_ticket_class.ticket_price))
        ticket_order.payments << payment
        ticket_order.status = Order::PROCESSED
        ticket_order.save!

      end

    end

    trait :paid_with_cash do

      association             :payment_type, :factory=>:cash_payment_type
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

    trait :paid_with_external do
      association               :payment_type, :factory=>:external_payment_type
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

  end


  trait :one_thousand_dollar_donation do
    association :payment_type, :factory=>:credit_card_payment_type
      after(:create) do |donation_order, evaluator|
        donation_order.donation_line_items << FactoryBot.create(:donation_line_item, :amount=>1000.00)
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
        credit_card_type                    { 'bogus' }
        credit_card_number                  { '4111111111111111' }
        credit_card_expiration_month        { '12' }
        credit_card_expiration_year         { Date.today.year.to_s }
        credit_card_verification_number     { '999' }
        after(:create) do |order, evaluator|
          order.create_proper_payment_in_amount_of!(order.value_of_all_line_items)
        end

      end

      factory :donation_pledge_order_for_one_thousand_dollars, :traits=>[:one_thousand_dollar_donation]
      factory :donation_pledge_order_for_one_thousand_dollars_using_credit_card, :traits=>[:one_thousand_dollar_donation, :paid_with_credit_card]
    end


  factory :special_offer_line_item do
    association :order, :factory => :order
  end


end
