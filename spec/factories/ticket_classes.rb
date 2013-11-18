FactoryGirl.define do

  factory :ticket_class do
    ticket_type 'Fixed'
    ticket_price 5.0
    sequence(:class_code) { |n| "GEN#{'%02d' % n}" }
    association :production
    auto_attach true
    web_visible true
    holds_seats true
    factory :software_managed_ticket_class do
      software_managed true
      web_visible false
    end
  end

end
