namespace :membership_offers do
  desc 'Enqueue a Stripe billing-period sync for every membership offer with a price_id'
  task sync_billing_periods: :environment do
    ids = MembershipOffer.where.not(price_id: [nil, '']).pluck(:id)
    ids.each { |id| Resque.enqueue(SyncMembershipOfferBillingPeriodJob, id) }
    puts "Enqueued billing-period sync for #{ids.size} membership offers."
  end
end
