FactoryBot.define do
  factory :service_item_template do
    sequence(:name) { |n| "ServiceItem#{n}" }
    sequence(:description) { |n| "Service Fee#{n}" }
    amount        { 5.0 }
    facility_fee  { 1.0 }
  end
end
