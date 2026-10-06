class AddExpiresOnToMemberships < ActiveRecord::Migration[6.1]
  # The last day a one-time (gift) membership is good for. Set at purchase from
  # the offer's term; ExpireOneTimeMembershipsJob closes the membership the day
  # after. NULL for subscriptions, which Stripe ends.
  def change
    add_column :memberships, :expires_on, :date
  end
end
