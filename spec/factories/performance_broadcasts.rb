FactoryBot.define do
  factory :performance_broadcast do
    association :performance
    association :user

    subject { "Important update regarding #{performance.production.name}" }
    from_address { 'boxoffice@theaterwit.org' }
    body { "This is a test broadcast message.\n\n**Important information** for attendees." }
    recipient_count { nil }
    sent_at { nil }
  end
end
