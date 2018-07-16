
# FactoryBot.duplicate_attribute_assignment_from_initialize_with = false

module FactoryBot
  class << self
    alias_method :original_create, :create

    def create(name, overrides = {})
      original_create(name, overrides)
    end

    def create_test_theater
      theater = FactoryBot.create(:theater, :name=>"Test Theater")
      production = FactoryBot.create(:production, :theater=>theater, :name=>"Production One",
                          :production_code=>"TEST", :opening_at=>Date.today, :closing_at=>Date.today)
      FactoryBot.create(:ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>1.00, :web_visible=>false, :software_managed=>true,
                          :production=>production) if TicketClass.where("production_id = ? and class_code = 'PASS'",production.id).count(:class_code) == 0
      FactoryBot.create(:ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'CHEAP', :class_name=>"Cheap Ticket",
                          :ticket_price=>5.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'RICH', :class_name=>"Expensive Ticket",
                          :ticket_price=>10.00, :web_visible=>true, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:ticket_class, :class_code=>'SECRET', :class_name=>"Secret Ticket",
                          :ticket_price=>20.00, :web_visible=>false, :software_managed=>false,
                          :production=>production)
      FactoryBot.create(:cash_payment_type, :allow_for_public=>false)
      FactoryBot.create(:credit_card_payment_type, :allow_for_public=>true)
      FactoryBot.create(:flex_pass_payment_type, :allow_for_public=>true)
      FactoryBot.create(:membership_payment_type, :allow_for_public=>true)
      FactoryBot.create(:default_ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
                          :ticket_price=>1.00, :web_visible=>false, :software_managed=>true, :auto_attach=>true)
      FactoryBot.create(:default_ticket_class, :class_code=>'PASSFRIEND', :class_name=>"Pass Ticket",
                          :ticket_price=>0.00, :web_visible=>false, :software_managed=>true, :auto_attach=>true)
      production.reload
      performance = FactoryBot.create(:performance, :production=>production, :performance_code=>'PERF', :performance_time=>"#{Date.today} 18:00".to_time)

      performance.ticket_class_allocations.each do |tca|
        tca.available = true
        tca.save!
      end

    end
  end



end

FactoryBot.define do


  factory :default_ticket_class do
    web_visible false
    ticket_price 0
    ticketing_fee 0
    holds_seats true
  end

  factory :user do
    sequence(:email) { |n| "stagemgr#{n}@example.com" }
    password 'password'
    password_confirmation 'password'
    is_administrator 0
    factory :admin_user do
      is_administrator 1
    end
  end

  factory :address do
    last_name 'Test'
    full_name 'Jeremy Test'
    first_name 'Jeremy'
    line1 '123 swift st'
    city 'hoboken'
    state 'ct'
    zipcode 90210
    email 'jeremy@test.com'
  end

  factory :credit_card_payment_type do
    display_name "Credit Card"
    initialize_with { CreditCardPaymentType.find_or_create_by(id:1)}
  end

  factory :cash_payment_type do
    display_name "Cash"
    initialize_with { CashPaymentType.find_or_create_by(id:2)}
  end

  factory :membership_payment_type do
    display_name "Membership"
    initialize_with { MembershipPaymentType.find_or_create_by(id:3)}
   end

  factory :flex_pass_payment_type do
    initialize_with { FlexPassPaymentType.find_or_create_by(id:4) do |p|
      p.display_name = 'Flex Pass'
    end}
  end

  factory :external_payment_type do
    display_name 'External Payment'
    initialize_with { ExternalPaymentType.find_or_create_by(id:5)}
  end

  factory :check_payment_type do
    display_name 'Check'
    initialize_with { CheckPaymentType.find_or_create_by(id:6)}
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
      transient do
        venue_count 1
      end
    end

  end


  factory :ticket_class_allocation do
    association :performance
    association :ticket_class, :factory=>:ticket_class
    available true
  end

  factory :flex_pass_offer do
    price 100.0
    number_of_tickets 10
    name 'Flex Pass'
    use_ticket_class_code 'PASS'
    active true
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

  factory :membership_line_item do
    association :membership_offer, :factory => :membership_offer
  end

  factory :donation_line_item do
    association :order, :factory=>:donation_order
  end

  factory :amount_off_special_offer do
    amount 1
    sequence(:code) { |n| "SpecialOffer#{n}" }
  end

  factory :membership_offer do
    name 'Test membership'
    recurring_cost BigDecimal.new("5.00")
    use_ticket_class_code 'PASS'
    tickets_per_performance 1
  end


end

