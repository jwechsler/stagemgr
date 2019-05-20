# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :order_task_suppression do
    task_type         { "OutreachTask" }
    method_name       { "ticket_confirmation" }
  end
end
