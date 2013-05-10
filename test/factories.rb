require 'declarative_authorization/maintenance'
include Authorization::Maintenance

FactoryGirl.duplicate_attribute_assignment_from_initialize_with = false

module FactoryGirl
  class << self
    alias_method :original_create, :create

    def create(name, overrides = {})
      without_access_control do
        original_create(name, overrides)
      end
    end

    def create_test_theater
      theater = FactoryGirl.create(:theater, :name=>"Test Theater")
      production = FactoryGirl.create(:production, :theater=>theater, :name=>"Production One",
                          :production_code=>"TEST")
      FactoryGirl.create(:ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>1.00, :web_visible=>false, :software_managed=>true,
                          :production=>production) if TicketClass.count(:class_code, :conditions=>["production_id = ? and class_code = 'PASS'",production.id]) == 0
      FactoryGirl.create(:ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>production)
      FactoryGirl.create(:ticket_class, :class_code=>'CHEAP', :class_name=>"Cheap Ticket",
                          :ticket_price=>5.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryGirl.create(:ticket_class, :class_code=>'RICH', :class_name=>"Expensive Ticket",
                          :ticket_price=>10.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryGirl.create(:ticket_class, :class_code=>'SECRET', :class_name=>"Secret Ticket",
                          :ticket_price=>20.00, :web_visible=>false, :software_managed=>false,
                          :production=>production)
      FactoryGirl.create(:cash_payment_type)
      FactoryGirl.create(:credit_card_payment_type)
      FactoryGirl.create(:flex_pass_payment_type)
      FactoryGirl.create(:membership_payment_type)
      performance = FactoryGirl.create(:performance, :production=>production, :performance_code=>'PERF')
      FactoryGirl.create(:default_ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>1.00, :web_visible=>false, :software_managed=>true)
      FactoryGirl.create(:default_ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true)

      performance.ticket_class_allocations.each do |tca|
        tca.available = true
        tca.save!
      end

    end
  end


end

FactoryGirl.define do


  factory :default_ticket_class do
    web_visible false
    ticket_price 0
    ticketing_fee 0
  end

  factory :user do
    sequence(:email) { |n| "stagemgr#{n}@example.com" }
    password 'password'
    password_confirmation 'password'
  end

  factory :address do
    last_name 'Test'
    full_name 'Test'
    line1 '123 swift st'
    city 'hoboken'
    state 'ct'
    zipcode 90210
  end

  factory :credit_card_payment_type do
    display_name "Credit Card"
    initialize_with { CreditCardPaymentType.find_or_create_by_id(1)}
  end

  factory :cash_payment_type do
    display_name "Cash"
    initialize_with { CashPaymentType.find_or_create_by_id(2)}
  end

  factory :membership_payment_type do
    display_name "Membership"
    initialize_with { MembershipPaymentType.find_or_create_by_id(3)}
   end

  factory :flex_pass_payment_type do
    initialize_with { FlexPassPaymentType.find_or_create_by_id(4) do |p|
      p.display_name = 'Flex Pass'
    end}


  end


  factory :venue do
    sequence(:name) { |n| "Space #{n}" }
    sequence(:ordinal_sort) { |n| "#{n}" }
  end

  factory :theater do

    sequence(:name) { |n| "Theater \##{n}" }
    theater_class Theater::THEATER_CLASSES.first
    status Theater::THEATER_STATUSES.first
    logo nil

    factory :theater_with_venues do
      ignore do
        venue_count 1
      end
    end

  end

  factory :ticket_class do
    ticket_type 'Fixed'
    ticket_price 5.0
    sequence(:class_code) { |n| "GEN#{'%02d' % n}" }
    association :production
    auto_attach true
    web_visible true
    factory :software_managed_ticket_class do
      software_managed true
      web_visible false
    end
  end

  factory :ticket_class_allocation do
    association :performance
    association :ticket_class, :factory=>:ticket_class
    available true
  end

  factory :production do
    sequence(:name) { |n| "Production \##{n}" }
    sequence(:production_code) { |n| "PRO#{'%02d' % n}" }
    status Production::PRODUCTION_STATUSES.first
    association :theater, :factory => :theater
    association :venue, :factory => :venue
    capacity 100
    closing_at Date.today + 1.week
    season Date.today.year

    ignore do
      ticket_class_count 1
    end

    after(:create) do |production, evaluator|
      FactoryGirl.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      FactoryGirl.create(:software_managed_ticket_class, :class_code=>'PASS', :production=>production )
    end

  end

  factory :performance do
    association :production, :factory => :production
    status Performance::PERFORMANCE_STATUSES.first
    sequence(:performance_code) { |n| "PF#{'%02d' % n}" }
    after(:create) { |perf| perf.ticket_class_allocations << FactoryGirl.create(:ticket_class_allocation, :performance=>perf, :available=>true)
      perf.populate_ticket_class_allocations
    }
  end


 # factory :base_order do |order|

  #end

  trait :order do
    status Order::ORDER_STATUSES.first
    association :address, :factory => :address
    association :payment_type, :factory=>:cash_payment_type
  end

  factory :ticket_order do
    order
    association :performance, :factory => :performance

    trait :for_a_pair_of_tickets do

      after(:create) do |ticket_order, evaluator|
        ticket_line_item = FactoryGirl.create :ticket_line_item,
          :ticket_class=>ticket_order.performance.ticket_class_allocations.select{|tca| tca.available }.first.ticket_class,
          :ticket_count=>2,
          :order=>ticket_order
      end

    end

    trait :paid_with_flex_pass do
      ignore do
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
        num_tix = TicketLineItem.sum(:ticket_count, :conditions=>['id = ?', ticket_order.id])
        ticket_order.payments << FactoryGirl.create(:flex_pass_payment,
                            :order=>ticket_order,
                            :number_of_tickets=>num_tix,
                            :flex_pass_id => FlexPass.find_by_code(evaluator.flex_pass_code).id,
                            :amount=>(num_tix * new_ticket_class.ticket_price))
        ticket_order.status = Order::PROCESSED
        ticket_order.save!
      end
    end


    factory :ticket_order_for_a_pair_of_tickets_paid_with_flexpass, :traits=>[:for_a_pair_of_tickets, :paid_with_flex_pass]

  end



  factory :flex_pass_offer do
    price 100.0
    number_of_tickets 10
    name 'Flex Pass'
    use_ticket_class_code 'PASS'
    active true
    payout_per_ticket 1.00
  end

  factory :flex_pass do
    code 'TESTPASS'
    association :flex_pass_offer, :factory => :flex_pass_offer
    association :flex_pass_line_item, :factory=>:flex_pass_line_item

    after(:build) { |flex_pass|
      flex_pass.order = flex_pass.flex_pass_line_item.order
      flex_pass.address = flex_pass.order.address
    }
  end

  factory :flex_pass_order do
    order
  end

  factory :donation_order do
    order
  end

  factory :special_offer_line_item do
    association :order, :factory => :order
  end

  factory :flex_pass_line_item do
    association :order, :factory=>:flex_pass_order
    association :flex_pass_offer, :factory=>:flex_pass_offer
    ticket_count 1
  end

  factory :ticket_line_item do
    association :ticket_class, :factory => :ticket_class
  end

  factory :donation_line_item do
    association :order, :factory=>:donation_order
  end

  factory :amount_off_special_offer do
    amount 1
    sequence(:code) { |n| "SpecialOffer#{n}" }
  end

  factory :payment do
    amount 0

    factory :cash_payment do
      type 'CashPayment'
    end

    factory :membership_payment do
      type 'MembershipPayment'

    end

    factory :flex_pass_payment do
      type 'FlexPassPayment'

    end

  end

  factory :membership_offer do
    name 'Test membership'
    recurring_cost BigDecimal.new("5.00")
    use_ticket_class_code 'MEMBER'
    tickets_per_performance 1
  end

end

