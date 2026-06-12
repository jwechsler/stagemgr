FactoryBot.define do
  factory :seat do
    row     { "AA" }
    zone    { "" }

    sequence(:seat_number) { |n| n }
    sequence(:location) { |n| "AA#{n}" }
  end
end
