FactoryBot.define do

  factory :performance do

    association :production, :factory => :production

    trait :with_custom_label do
      association :production, :factory => :production_with_custom_label
    end

    status Performance::PERFORMANCE_STATUSES.first
    sequence(:performance_code) { |n| "#{production.production_code}#{'%02d' % n}" }
    after(:create) {
      |perf| perf.ticket_class_allocations << FactoryBot.create(:ticket_class_allocation, :performance=>perf, :available=>true)
      perf.populate_ticket_class_allocations
    }
    performance_date Date.today
    sequence (:performance_time) { |n| Time.now + 1.second}
  end

end
