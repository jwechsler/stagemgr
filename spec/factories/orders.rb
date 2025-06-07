FactoryBot.define do

  trait :order do
    status                  { Order::ORDER_STATUSES.first }
    association             :address, :factory => :address
    association             :payment_type, :factory=>:cash_payment_type
  end


  factory :ticket_order do
    order

    trait :with_twenty_dollar_service_item do
   
      before(:create) do |ticket_order, evaluator|
        ticket_order.service_line_items << FactoryBot.create(:service_line_item, facility_fee: 2.00, amount: 20.00, order: ticket_order)
      end

    end
    
    trait :with_wierd_special_offer do
      before(:create) do |ticket_order, evaluator|
        ticket_order.special_offer_line_item = FactoryBot.create(:special_offer_line_item, order: ticket_order, special_offer: FactoryBot.create(:percent_off_special_offer, code: 'WEIRDOFFER', amount: 17))
      end

    end

    performance factory: :general_admission

    trait :general_admission do
      performance factory: :general_admission
    end

    trait :reserved_seating do
      performance factory: :reserved_seating
    end

    trait :for_a_single_ticket do
      before(:create) do |ticket_order, evaluator|
        # Assume there is a method to find a suitable ticket class
        ticket_class = ticket_order.performance.ticket_class_allocations.select{|tca| tca.available}.first.ticket_class
        ticket_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
          ticket_class: ticket_class,
          ticket_count: 1,  # Only 1 ticket in this order
          order: ticket_order)
      end
    end

    trait :for_three_tickets do
      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << [FactoryBot.build(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available && !tca.ticket_class.software_managed? && tca.ticket_class.ticket_price > 0 }.sort{|tca1, tca2| tca2.ticket_class.ticket_price <=> tca1.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order),
        FactoryBot.build(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.sort{|tca1, tca2| tca1.ticket_class.ticket_price <=> tca2.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>1,
          :order=>ticket_order)]
      end

    end

    trait :for_a_pair_of_tickets do
      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available && !tca.ticket_class.software_managed? && tca.ticket_class.ticket_price > 0 }.sort {|tca1, tca2| tca2.ticket_class.ticket_price <=> tca1.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order) 
      end
    end

    trait :for_an_expensive_pair_of_tickets do
      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.sort{|tca1, tca2| tca2.ticket_class.ticket_price <=> tca1.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
      end
    end

    trait :for_a_cheap_pair_of_tickets do
      before(:create) do |ticket_order, evaluator|
        ticket_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.sort{|tca1, tca2| tca1.ticket_class.ticket_price <=> tca2.ticket_class.ticket_price}.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order)
      end
    end

    # make sure seats are assigned if tickets registered
    after(:create) do |ticket_order,evaluator| 
      if ticket_order.performance.production.has_reserved_seating? then
        seats_required = ticket_order.number_of_seats - ticket_order.seats.size
        remaining_seats = ticket_order.performance.seat_assignments.select{|sa| !sa.assigned?}
        remaining_seats_index = 0
        ticket_order.ticket_line_items.each do |tli|
          tli.ticket_count.times do
            seat = remaining_seats[remaining_seats_index]
            seat.order_uuid = ticket_order.uuid
            seat.ticket_class_id = tli.ticket_class_id
            seat.status = SeatAssignment::ASSIGNED
            ticket_order.seats << seat
            remaining_seats_index += 1
            seats_required += -1
          end
        end

        ticket_order.flatten_ticket_line_items.select{|t| t[:seat].nil? }.each do |flattened_item|
          if seats_required > 0 then
            
            ticket_order.seats << remaining_seats[remaining_seats_index]
            remaining_seats_index += 1
            seats_required += -1
          end
        end
      end
    end

    # payment traits

    trait :paid_with_credit_card do

      association           :payment_type, :factory=>:credit_card_payment_type
      after(:create) do |ticket_order, evaluator|
        num_tix = TicketLineItem.where(order_id:ticket_order.id).sum(:ticket_count)
        ticket_order.payments << FactoryBot.create(:credit_card_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>ticket_order.total_due,
                            :transaction_id => 'TEST_TRANSACTION',
                            :confirmation_code => 'CONFIRMED',
                            :card_type=>'bogus',
                            :card_last_four=>'1111')
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :paid_with_flex_pass do
      transient do
        flex_pass_code      { '' }
      end
      association :payment_type, :factory=>:flex_pass_payment_type

      before(:create) do |ticket_order, evaluator|
        if evaluator.flex_pass_code.blank?
          flex_pass = FactoryBot.create(:flex_pass)
        else
          flex_pass = FactoryBot.create(:flex_pass, code:evaluator.flex_pass_code)
        end


        find_code = flex_pass.flex_pass_offer.use_ticket_class_code
        ticket_order.performance.production.ticket_classes << (pass_class = FactoryBot.create(:ticket_class, :class_code=>find_code, :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>ticket_order.performance.production, :auto_attach=>true))
        
        ticket_order.performance.ticket_class_allocations << FactoryBot.build(:ticket_class_allocation, available: true, ticket_class: pass_class)
        ticket_order.flex_pass_code = flex_pass.code
      end

      after(:create) do |ticket_order, evaluator|
        flex_pass = FlexPass.find_by(code:ticket_order.flex_pass_code)
        find_code = flex_pass.flex_pass_offer.use_ticket_class_code
        new_ticket_class = ticket_order.performance.ticket_class_allocations.select {|tca|
          tca.ticket_class.class_code.eql?(find_code) }.first.ticket_class
        ticket_order.ticket_line_items.each do |tli|
          tli.ticket_class = new_ticket_class
        end
        
        ticket_order.adjust_seating_to_match_ticket_line_items
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        ticket_order.payments << FactoryBot.create(:flex_pass_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :flex_pass => flex_pass,
                            :amount=>(num_tix * new_ticket_class.ticket_price))

        if ticket_order.service_line_items.size > 0 then
          ticket_order.payments << FactoryBot.create(:cash_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>(ticket_order.service_line_items.inject(0){ |total, sli| total += sli.amount }))
        end
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end

    trait :paid_with_membership do

      association :payment_type, :factory=>:membership_payment_type

      before(:create) do |ticket_order, evaluator|
        if evaluator.member_code.blank?
          membership = FactoryBot.create(:membership, address: ticket_order.address)
        else
          membership = FactoryBot.create(:membership, address: ticket_order.address, member_code:evaluator.member_code)
        end
        find_code = membership.membership_offer.use_ticket_class_code

        if (ticket_order.performance.production.ticket_classes.select{|tc| tc.class_code.eql?(find_code)}.size == 0)
          tc = FactoryBot.create(:ticket_class, :class_code=>find_code, :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>ticket_order.performance.production, :auto_attach=>true)
          ticket_order.performance.reload
          ticket_order.performance.ticket_class_allocations.reload
        end

        ticket_order.member_code = membership.member_code

      end

      after(:create) do |ticket_order, evaluator|
        membership = Membership.find_by(member_code:ticket_order.member_code)
        find_code = membership.membership_offer.use_ticket_class_code

        new_ticket_class = ticket_order.performance.ticket_class_allocations.select {|tca|
          tca.ticket_class.class_code == find_code }.first.ticket_class
        ticket_order.ticket_line_items.each do |tli|
          tli.ticket_class = new_ticket_class
        end
        ticket_order.adjust_seating_to_match_ticket_line_items
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        payment = FactoryBot.create(:membership_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :membership => membership,
                            :amount=>(num_tix * new_ticket_class.ticket_price))

        ticket_order.payments << payment
        if ticket_order.service_line_items.size > 0 then
          ticket_order.payments << FactoryBot.create(:cash_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :amount=>(ticket_order.service_line_items.inject(0){ |total, sli| total += sli.amount }))
        end
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
                            :amount=>ticket_order.total_due)
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
        
      end
    end

    trait :paid_with_external do
      association               :payment_type, :factory=>:external_payment_type
      after(:create) do |ticket_order, evaluator|
        num_tix = ticket_order.ticket_line_items.inject(0){|sum, tli| sum += tli.ticket_count }
        ticket_order.payments << FactoryBot.create(:external_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :payment_type_id => ticket_order.payment_type_id,
                            :amount=>ticket_order.total_due)
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
