class AddTicketsPerPerformanceToMembershipOffers < ActiveRecord::Migration
  def self.up
    add_column :membership_offers, :tickets_per_performance, :integer
  end

  def self.down
    remove_column :membership_offers, :tickets_per_performance
  end
end
