FactoryBot.define do
  trait :special_offer do
    sequence(:code) { |n| "OFFER#{'%02d' % n}" }
  end

  factory :percent_off_special_offer do
    special_offer
    amount            { 50 }
  end

  factory :amount_off_special_offer do
    amount            { 1 }
    sequence(:code) { |n| "SpecialOffer#{n}" }
  end

  factory :buy_x_get_y_special_offer do
    special_offer
    buy_quantity      { 2 }
    get_quantity      { 1 }
  end
end
