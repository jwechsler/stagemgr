FactoryBot.define do
  # NOTE: deliberately NO initialize_with find_or_create_by here. The
  # ticket_class factory does that on class_code alone, which silently returns a
  # class belonging to a different production; the sequenced code plus a plain
  # create keeps every resource in a spec distinct.
  factory :resourced_ticket_class do
    sequence(:class_code) { |n| format('RES%02d', n) }
    sequence(:class_name) { |n| "Captioning Tablet #{n}" }
    ticket_type        { 'Fixed' }
    ticket_price       { 0 }
    ticketing_fee      { 0 }
    quantity           { 2 }
    changeover_minutes { 30 }
    holds_seats        { false }
    web_visible        { true }
    software_managed   { false }

    transient do
      venue_count { 1 }
    end

    # create_list (not build_list) so the venue factory's after(:create) hook
    # runs and the venue gets its seat map, matching a real venue.
    venues { create_list(:venue, venue_count) }
  end
end
