# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :order_task_suppression do
    task_type "OutreachTask"
    method_name "ticket_confirmation"
  end
end
