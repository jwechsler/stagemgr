FactoryBot.define do
  factory :seat do
    sequence(:seat_number) { |n| n }
    row "AA"
    sequence(:location) { |n| "AA#{n}" }
    zone ""
  end
end
