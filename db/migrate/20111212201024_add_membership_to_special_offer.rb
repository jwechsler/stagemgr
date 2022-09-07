class AddMembershipToSpecialOffer < ActiveRecord::Migration[4.2]
  def self.up
    add_column :special_offers, :membership_id, :integer
  end

  def self.down
    remove_column :special_offers, :membership_id
  end
end
