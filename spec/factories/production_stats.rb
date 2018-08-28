# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :production_stat do
    production_id 1
    total_ticket_sales 1.5
    average_ticket_price 1.5
    total_comps 1
    number_of_tickets 1
  end
end
