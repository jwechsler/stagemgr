FactoryBot.define do
  factory :performance do
    association :production, factory: :production

    trait :with_custom_label do
      association :production, factory: :production_with_custom_label
    end

    factory :reserved_seating do
      association :production, factory: :production_with_reserved_seating
    end

    factory :general_admission do
    end

    status { Performance::PERFORMANCE_STATUSES.first }
    sequence(:performance_code) { |n| "#{production.production_code}#{'%02d' % n}" }
    after(:create) do |perf|
      perf.production.ticket_classes.each do |tc|
        next if perf.ticket_class_allocations.map do |tca|
          tca.ticket_class
        end.include?(tc)

        perf.ticket_class_allocations << FactoryBot.create(:ticket_class_allocation, performance: perf,
                                                                                     available: true, ticket_class: tc)
      end
      perf.populate_ticket_class_allocations
    end

    performance_date { Date.today }
    sequence(:performance_time) { |_n| Time.now + 1.minute }
    initialize_with { Performance.find_or_create_by(performance_code: performance_code) }
  end
end
