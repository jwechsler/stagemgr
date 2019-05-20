FactoryBot.define do
  factory :venue do
     sequence(:name) { |n| "Space #{n}" }
     sequence(:ordinal_sort) { |n| "#{n}" }
   end

end
