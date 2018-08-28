FactoryBot.define do
  factory :seat_map do
    trait :with_seats do
      after(:create) do |seat_map, evaluator|
        8.times do 
          seat_map.seats << FactoryBot.create(:seat)
        end
      end
    end
    label "Tiny House"
    association :venue, factory: :venue

    factory :seat_map_with_seats, traits: [:with_seats]
  end
end
