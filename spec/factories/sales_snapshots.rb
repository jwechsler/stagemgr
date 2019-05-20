# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :sales_snapshot do
    as_of_date          { "2013-10-18" }
    production_stat_id  { 1 }
    advance_sales       { 0.0 }
    advance_seats       { 0 }
    daily_sales         { 0.0 }
    sales_to_date       { 0.0 }
    seats_to_date       { 0.0 }
  end
end
