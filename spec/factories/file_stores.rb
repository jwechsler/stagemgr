# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :file_store do
    user_id   { 1 }
    name      { "MyString" }
    hash      { "MyString" }
    worker    { "MyString" }
  end
end
