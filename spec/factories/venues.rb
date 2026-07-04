FactoryBot.define do
  factory :venue do
    sequence(:name) { |n| "Space #{n}" }
    sequence(:ordinal_sort) { |n| n.to_s }
    transient do
      seat_map_count { 1 }
    end

    after(:create) do |venue, evaluator|
      create_list(:seat_map, evaluator.seat_map_count, venue: venue)
    end
  end
end
