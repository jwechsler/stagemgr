FactoryBot.define do
  factory :festival do
    sequence(:name) { |n| "Festival ##{n}" }
    status { Festival::ACTIVE }
    short_description { 'A celebration of remarkable performance' }
    description { 'An extended description of the festival and its offerings.' }

    trait :with_landing_page do
      landing_page_enabled { true }
    end

    trait :inactive do
      status { Festival::INACTIVE }
    end

    trait :with_productions do
      transient do
        production_count { 2 }
      end

      after(:create) do |festival, evaluator|
        FactoryBot.create_list(:production, evaluator.production_count, festival: festival)
      end
    end
  end
end
