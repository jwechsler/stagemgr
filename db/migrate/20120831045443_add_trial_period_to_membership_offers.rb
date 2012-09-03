class AddTrialPeriodToMembershipOffers < ActiveRecord::Migration
  def change
    add_column :membership_offers, :trial_period, :integer, :default=>0
  end
end
