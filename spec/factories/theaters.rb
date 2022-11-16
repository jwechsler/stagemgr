FactoryBot.define do

  factory :theater do
    theater_class   { Theater::THEATER_CLASSES.first }
    status          { Theater::THEATER_STATUSES.first }
    logo            { nil }
    accepts_donations { false }

    sequence(:name) { |n| "Theater \##{n}" }

    factory :theater_with_venues do
      transient do
        venue_count { 1 }
      end
    end

    initialize_with { Theater.find_or_create_by(name: name) }
  end

end
