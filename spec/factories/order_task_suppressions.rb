# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_task_suppression do
    task_type         { 'OutreachTask' }
    method_name       { 'ticket_confirmation' }

    trait :any_method do
      method_name { 'ANY' }
    end

    trait :nil_method do
      method_name { nil }
    end
  end
end
