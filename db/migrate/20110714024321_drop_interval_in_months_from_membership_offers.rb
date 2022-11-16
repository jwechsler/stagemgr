class DropIntervalInMonthsFromMembershipOffers < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :membership_offers, :interval_in_months
  end

  def self.down
    add_column :membership_offers, :interval_in_months, :integer
  end
end
