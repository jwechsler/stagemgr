class AddMembershipToSpecialOffer < ActiveRecord::Migration
  def self.up
    add_column :special_offers, :membership_id, :integer
  end

  def self.down
    remove_column :special_offers, :membership_id
  end
end
