class AddBillingPeriodToMembershipOffers < ActiveRecord::Migration[6.1]
  # The billing period of the offer's Stripe Price, cached by
  # SyncMembershipOfferBillingPeriodJob. billing_interval is day, week, month,
  # year or one_time; NULL means not synced yet (treated as monthly).
  def change
    change_table :membership_offers, bulk: true do |t|
      t.string :billing_interval
      t.integer :billing_interval_count
      t.datetime :billing_period_synced_at
    end
  end
end
