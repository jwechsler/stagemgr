# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :pledge do
    order_id    { "" }
    profile_id  { "MyString" }
    address_id  { "" }
  end
end
