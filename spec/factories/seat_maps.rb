FactoryBot.define do
  factory :seat_map do
    trait :with_seats do
      after(:create) do |seat_map, evaluator|
        8.times do
          seat_map.seats << FactoryBot.create(:seat)
        end
      end
    end
    label         { "Tiny House" }
    association :venue, factory: :venue
  end
end
