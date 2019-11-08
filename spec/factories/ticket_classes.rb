FactoryBot.define do

  factory :default_ticket_class do
    web_visible     { false }
    ticket_price    { 0 }
    ticketing_fee   { 0 }
    holds_seats     { true }
    sequence(:class_code) { |n| "GEN#{'%02d' %n}" }
    sequence(:class_name) { |n| "General #{n}"}
    ticket_type      { 'Fixed' }
    initialize_with { DefaultTicketClass.find_or_create_by(class_code: class_code) }
  end

  factory :ticket_class do
    ticket_type       { 'Fixed' }
    ticket_price      { 5.0 }
    ticketing_fee     { 0.0 }
    production
    auto_attach       { true }
    web_visible       { true }
    holds_seats       { true }
    software_managed  { false }
    sequence(:class_code) { |n| "GEN#{'%02d' % n}" }
    sequence(:class_name) { |n| "General #{n}"}
    trait :software_managed do
      software_managed   { true }
      web_visible        { false }
    end

    initialize_with { TicketClass.find_or_create_by(class_code: class_code) }
  end

  factory :ticket_class_allocation do
    association :performance
    association :ticket_class, :factory=>:ticket_class
    available            { true }
  end

end
