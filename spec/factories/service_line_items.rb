FactoryBot.define do
  factory :service_line_item do
    amount            { 5.00 }
    facility_fee      { 2.00 }
    description       { "Test Service Charge" }
    association :order, :factory => :order
  end
end
