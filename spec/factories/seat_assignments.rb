FactoryBot.define do
  factory :seat_assignment do
    order         { '' }
    seat          { '' }
    seat_map      { '' }
    status        { 'Available' }
  end
end
