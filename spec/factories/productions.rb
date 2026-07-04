FactoryBot.define do
  factory :production do
    status                  { Production::PRODUCTION_STATUSES.first }
    capacity                { 100 }
    closing_at              { Date.today + 1.week }
    opening_at              { Date.today }
    press_opening_at        { Date.today }
    first_preview_at        { Date.today }
    season                  { Date.today.year }
    seat_map                { nil }
    running_time            { 120 }
    theater
    venue

    sequence(:name) { |n| "Production ##{n}" }
    sequence(:production_code) { |n| "PRD#{'%02d' % n}" }

    transient do
      ticket_class_count { 2 }
    end

    after(:create) do |production, _evaluator|
      if production.ticket_classes.empty?
        FactoryBot.create(:ticket_class, ticket_price: BigDecimal(2.50, 2), production: production)
        FactoryBot.create(:ticket_class, ticket_price: BigDecimal(6, 2), production: production)
        FactoryBot.create(:ticket_class, class_code: 'PASS', ticket_price: BigDecimal(6, 2), production: production)
      end
      # evaluator.ticket_class_count.times do
      #  production.ticket_classes << FactoryBot.create(:ticket_class)
      # end
      # FactoryBot.create_list(:ticket_class, evaluator.ticket_class_count, :production=>production)
      # production.ticket_classes << FactoryBot.create(:ticket_class, :class_code=>'PASS', :class_name=>"Pass Ticket",
      #                     :ticket_price=>0.00, :web_visible=>false, :software_managed=>true,
      #                     :auto_attach=>true,
      #                     :production=>production)
    end

    initialize_with { Production.find_or_create_by(production_code: production_code) }

    factory :production_with_custom_label do
      custom_label { 'special secret class' }
    end

    factory :production_with_reserved_seating do
      before(:create) do |production, _evaluator|
        production.seat_map = production.venue.seat_maps.first
      end
    end
  end
end
