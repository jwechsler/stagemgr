FactoryBot.define do
  factory :production do
    sequence(:name) { |n| "Production \##{n}" }
    sequence(:production_code) { |n| "PRO#{'%02d' % n}" }
    status Production::PRODUCTION_STATUSES.first
    association :theater, :factory => :theater
    association :venue, :factory => :venue
    capacity 100
    closing_at Date.today + 1.week
    opening_at Date.today
    season Date.today.year

    transient do
      ticket_class_count 1
    end

    after(:create) do |production, evaluator|
      if production.ticket_classes.empty?
        FactoryBot.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      end
      #evaluator.ticket_class_count.times do
      #  production.ticket_classes << FactoryBot.create(:ticket_class)
      #end
      #FactoryBot.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      FactoryBot.create(:software_managed_ticket_class, :class_code=>'PASS', :production=>production )
    end

  end

  factory :production_with_custom_label, class: Production, parent: :production do
    custom_label "special secret class"
  end

end
