class RemoveBillingAgreementFromMembershipOffers < ActiveRecord::Migration[6.1]
  # Added in 2011 for PayPal recurring payments, where the "billing agreement"
  # description was shown to the patron at authorization. Stripe never read it;
  # it had become a bare heading above the offer description on checkout.
  def change
    remove_column :membership_offers, :billing_agreement, :text, size: :medium
  end
end
