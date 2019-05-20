FactoryBot.define do
  factory :production do
    status                  { Production::PRODUCTION_STATUSES.first }
    capacity                { 100 }
    closing_at              { Date.today + 1.week }
    opening_at              { Date.today }
    press_opening_at        { Date.today }
    first_preview_at        { Date.today }
    season                  { Date.today.year }

    theater
    venue

    sequence(:name) { |n| "Production \##{n}" }
    sequence(:production_code) { |n| "PRD#{'%02d' % n}" }

    transient do
      ticket_class_count    { 1 }
    end

    after(:create) do |production, evaluator|
      if production.ticket_classes.empty?
        FactoryBot.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      end
      #evaluator.ticket_class_count.times do
      #  production.ticket_classes << FactoryBot.create(:ticket_class)
      #end
      #FactoryBot.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      FactoryBot.create(:ticket_class, :software_managed, :class_code=>'PASS', :production=>production )
    end
    initialize_with { Production.find_or_create_by(production_code: production_code) }

  end

  factory :production_with_custom_label, class: Production, parent: :production do
    custom_label      { "special secret class" }
  end

end
