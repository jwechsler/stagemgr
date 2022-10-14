FactoryBot.define do
  factory :flex_pass_offer do
    price                   { 100.0 }
    number_of_tickets       { 10 }
    name                    { 'Flex Pass' }
    use_ticket_class_code   { 'PASS' }
    active                  { true }
    on_sale_to_public       { true }

  end

  factory :flex_pass do
    code                    { 'TESTPASS' }
    expiration_date         { Date.today + 12.months}
    association :flex_pass_offer, :factory => :flex_pass_offer
    association :flex_pass_line_item, :factory=>:flex_pass_line_item

    after(:build) { |flex_pass|
      flex_pass.order = flex_pass.flex_pass_line_item.order
      flex_pass.address = flex_pass.order.address
    }
  end


  factory :flex_pass_line_item do
    association :order, :factory=>:flex_pass_order
    association :flex_pass_offer, :factory=>:flex_pass_offer
    ticket_count             { 1 }
  end

end
