require 'declarative_authorization/maintenance'
include Authorization::Maintenance

module FactoryGirl
  class << self
    alias_method :original_create, :create

    def create(name, overrides = {})
      without_access_control do
        original_create(name, overrides)
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
      ticket_type TicketClass::TICKET_TYPES.first
      ticket_price 5.0
      sequence(:class_code) { |n| "GEN#{'%02d' % n}" }
      production
    end

    factory :production do
      sequence(:name) { |n| "Production \##{n}" }
      sequence(:production_code) { |n| "PRO#{'%02d' % n}" }
      status Production::PRODUCTION_STATUSES.first
      association :theater, :factory => :theater
      association :venue, :factory => :venue
      capacity 100
      season Date.today.year

      factory :production_with_ticket_classes do
        ignore do
          ticket_class_count 1
        end

        after(:create) do |production, evaluator|
          FactoryGirl.create_list(:ticket_class, evaluator.ticket_class_count, production: production)
        end
      end
    end

    factory :performance do
      association :production, :factory => :production
      status Performance::PERFORMANCE_STATUSES.first
      sequence(:performance_code) { |n| "PF#{'%02d' % n}" }
      after(:build) { |perf| perf.populate_ticket_class_allocations }
    end


   # factory :base_order do |order|

    #end

    trait :order do
      status Order::ORDER_STATUSES.first
      association :address, :factory => :address
      payment_type Order::CASH
    end

    factory :ticket_order do
      order
      association :performance, :factory => :performance
    end

    factory :flex_pass_order do
      order
    end

    factory :special_offer_line_item do
      association :order, :factory => :order
    end

    factory :ticket_line_item do
      association :ticket_class, :factory => :ticket_class
    end

    factory :amount_off_special_offer do
      amount 1
      sequence(:code) { |n| "SpecialOffer#{n}" }
    end

    factory :payment do
      amount 0

      factory :cash_payment do
      end

      factory :membership_payment do

      end
    end

    factory :membership_offer do
      name 'Test membership'
      recurring_cost BigDecimal.new("5.00")
      use_ticket_class_code 'MEMBER'
    end

end

