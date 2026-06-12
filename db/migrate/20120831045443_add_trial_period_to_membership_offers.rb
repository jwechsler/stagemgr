class AddTrialPeriodToMembershipOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :membership_offers, :trial_period, :integer, default: 0
  end
end
