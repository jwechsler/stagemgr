class AddTrialOptionsToMembershipOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :membership_offers, :trial_price, :decimal
    add_column :membership_offers, :restricted_to_first_time, :boolean, default: false
  end
end
