FactoryBot.define do
  factory :seat_map do
    label { "Tiny House" }
    venue
    transient do
      seat_count { 8 }
    end

    after(:create) do |seat_map, evaluator|
      create_list(:seat, evaluator.seat_count, seat_map: seat_map)
    end
  end
end
