class AddMembershipOfferIdToLineItems < ActiveRecord::Migration
  def self.up
    add_column :line_items, :membership_offer_id, :integer
  end

  def self.down
    remove_column :line_items, :membership_offer_id
  end
end
